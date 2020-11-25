#!/usr/bin/env ruby

require "benchmark"
require "set"

# https://github.com/redding/a-lint-runner.rb
module ALintRunner
  VERSION = "0.0.1"

  # update these as needed for your lint setup
  BIN_NAME = "a-lint-runner"
  SOURCE_FILES = [
    "app", "config", "db", "lib", "script", "test"
  ]
  IGNORED_FILES = [
    "test/fixtures"
  ]
  LINTERS =
    [
      {
        name: "Rubocop",
        executable: "rubocop",
        extensions: [".rb"]
      },
      {
        name: "ES Lint",
        executable: "./node_modules/.bin/eslint",
        extensions: [".js"]
      },
      {
        name: "SCSS Lint",
        executable: "scss-lint",
        extensions: [".scss"]
      }
    ]

  class Config
    def self.settings(*items)
      items.each do |item|
        define_method(item) do |*args|
          if !(value = args.size > 1 ? args : args.first).nil?
            instance_variable_set("@#{item}", value)
          end
          instance_variable_get("@#{item}")
        end
      end
    end

    attr_reader :stdout, :version
    attr_reader :bin_name, :source_files, :ignored_files

    settings :changed_only, :changed_ref, :dry_run, :list, :debug

    def self.file_path_source_files(file_path)
      pwd = Dir.pwd
      path = File.expand_path(file_path, pwd)

      (Dir.glob("#{path}*") + Dir.glob("#{path}*/**/*"))
        .map{ |p| p.gsub("#{pwd}/", "") }
    end

    def self.root_source_files
      pwd = Dir.pwd

      Dir.glob("#{pwd}/*")
        .select{ |p| File.file?(p) }
        .map{ |p| p.gsub("#{pwd}/", "") }
    end

    Dir.glob(Dir.pwd + "/*")

    def initialize(stdout = nil)
      @stdout = stdout || $stdout

      @version       = VERSION
      @bin_name      = BIN_NAME
      @source_files  = SOURCE_FILES
      @ignored_files = IGNORED_FILES
      @linter_hashes = LINTERS

      # cli option settings
      @changed_only = false
      @changed_ref  = ""
      @dry_run      = false
      @list         = false
      @debug        = false
    end

    def source_whitelist
      @source_whitelist ||=
        source_files
          .reduce(Set.new(self.class.root_source_files)) { |acc, path|
            acc + self.class.file_path_source_files(path)
          }
          .sort
    end

    def source_blacklist
      @source_blacklist ||=
        ignored_files
          .reduce(Set.new) { |acc, path|
            acc + self.class.file_path_source_files(path)
          }
          .sort
    end

    def linters
      @linters ||= @linter_hashes.map{ |linter_hash| Linter.new(**linter_hash) }
    end

    def apply(settings)
      settings.keys.each do |name|
        if !settings[name].nil? && self.respond_to?(name.to_s)
          self.send(name.to_s, settings[name])
        end
      end
    end

    def debug_msg(msg)
      "[DEBUG] #{msg}"
    end

    def debug_puts(msg)
      self.puts debug_msg(msg)
    end

    def puts(msg)
      self.stdout.puts msg
    end

    def print(msg)
      self.stdout.print msg
    end

    def bench(start_msg, &block)
      if !self.debug
        block.call; return
      end
      self.print bench_start_msg(start_msg)
      RoundedMillisecondTime.new(Benchmark.measure(&block).real).tap do |time_in_ms|
        self.puts bench_finish_msg(time_in_ms)
      end
    end

    def bench_start_msg(msg)
      self.debug_msg("#{msg}...".ljust(30))
    end

    def bench_finish_msg(time_in_ms)
      " (#{time_in_ms} ms)"
    end

    private

    def source_root_files
      @source_whitelist ||=
        source_files
          .reduce(Set.new) { |acc, path|
            acc + self.class.file_path_source_files(path)
          }
          .sort
    end
  end

  class Linter
    ARGUMENT_SEPARATOR = " "

    attr_reader :name, :executable, :extensions

    def initialize(name:, executable:, extensions:)
      @name = name
      @executable = executable
      @extensions = extensions
    end

    def cmd_str(source_files)
      applicable_source_files =
        source_files.select { |source_file|
          @extensions.include?(File.extname(source_file))
        }
      return if applicable_source_files.none?

      "#{executable} #{applicable_source_files.join(ARGUMENT_SEPARATOR)}"
    end
  end

  class Runner
    DEFAULT_FILE_PATH = "."

    attr_reader :file_paths, :config

    def initialize(file_paths, config:)
      @file_paths = file_paths
      @config = config
    end

    def execute?
      any_source_files? && any_linters? && !dry_run? && !list?
    end

    def any_source_files?
      source_files.any?
    end

    def any_linters?
      config.linters.any?
    end

    def dry_run?
      !!config.dry_run
    end

    def list?
      !!config.list
    end

    def debug?
      !!config.debug
    end

    def changed_only?
      !!config.changed_only
    end

    def linters
      config.linters
    end

    def source_files
      @source_files ||=
        (found_source_files & config.source_whitelist) - config.source_blacklist
    end

    def cmds
      @cmds ||= linters.map { |linter| linter.cmd_str(source_files) }.compact
    end

    def run
      if debug?
        debug_puts "#{source_files.size} source files:"
        source_files.each do |source_file|
          debug_puts "  #{source_file}"
        end
      end

      if list?
        puts source_files.join("\n")
      else
        linters.each_with_index do |linter, index|
          puts "\n\n" if index > 0
          puts "Running #{linter.name}"

          if (cmd = linter.cmd_str(source_files))
            debug_puts "  #{cmd}" if debug?
            system(cmd) if execute?
            puts cmd if dry_run?
          end
        end
      end
    end

    private

    def found_source_files
      source_file_paths = file_paths.empty? ? [DEFAULT_FILE_PATH] : file_paths
      files = nil

      if changed_only?
        result = nil
        ALintRunner.bench("Lookup changed source files") do
          result = changed_source_files(source_file_paths)
        end
        files = result.files
        if debug?
          debug_puts "  `#{result.cmd}`"
        end
      else
        ALintRunner.bench("Lookup source files") do
          files = globbed_source_files(source_file_paths)
        end
      end

      files
    end

    def changed_source_files(source_file_paths)
      result = GitChangedFiles.new(config, source_file_paths)
      ChangedResult.new(result.cmd, globbed_source_files(result.files))
    end

    def globbed_source_files(source_file_paths)
      source_file_paths
        .reduce(Set.new) { |acc, source_file_path|
          acc + Config.file_path_source_files(source_file_path)
        }
        .sort
    end

    def puts(*args)
      config.puts(*args)
    end

    def debug_puts(*args)
      config.debug_puts(*args)
    end
  end

  ChangedResult = Struct.new(:cmd, :files)

  module GitChangedFiles
    def self.cmd(config, file_paths)
      [
        "git diff --no-ext-diff --name-only #{config.changed_ref}", # changed files
        "git ls-files --others --exclude-standard"                  # added files
      ]
        .map{ |c| "#{c} -- #{file_paths.join(" ")}" }
        .join(" && ")
    end

    def self.new(config, file_paths)
      cmd = self.cmd(config, file_paths)
      ChangedResult.new(cmd, `#{cmd}`.split("\n"))
    end
  end

  module RoundedMillisecondTime
    ROUND_PRECISION = 3
    ROUND_MODIFIER = 10 ** ROUND_PRECISION
    def self.new(time_in_seconds)
      (time_in_seconds * 1000 * ROUND_MODIFIER).to_i / ROUND_MODIFIER.to_f
    end
  end

  class CLIRB  # Version 1.1.0, https://github.com/redding/cli.rb
    Error    = Class.new(RuntimeError);
    HelpExit = Class.new(RuntimeError); VersionExit = Class.new(RuntimeError)
    attr_reader :argv, :args, :opts, :data

    def initialize(&block)
      @options = []; instance_eval(&block) if block
      require "optparse"
      @data, @args, @opts = [], [], {}; @parser = OptionParser.new do |p|
        p.banner = ""; @options.each do |o|
          @opts[o.name] = o.value; p.on(*o.parser_args){ |v| @opts[o.name] = v }
        end
        p.on_tail("--version", ""){ |v| raise VersionExit, v.to_s }
        p.on_tail("--help",    ""){ |v| raise HelpExit,    v.to_s }
      end
    end

    def option(*args); @options << Option.new(*args); end
    def parse!(argv)
      @args = (argv || []).dup.tap do |args_list|
        begin; @parser.parse!(args_list)
        rescue OptionParser::ParseError => err; raise Error, err.message; end
      end; @data = @args + [@opts]
    end
    def to_s; @parser.to_s; end
    def inspect
      "#<#{self.class}:#{"0x0%x" % (object_id << 1)} @data=#{@data.inspect}>"
    end

    class Option
      attr_reader :name, :opt_name, :desc, :abbrev, :value, :klass, :parser_args

      def initialize(name, desc = nil, abbrev: nil, value: nil)
        @name, @desc = name, desc || ""
        @opt_name, @abbrev = parse_name_values(name, abbrev)
        @value, @klass = gvalinfo(value)
        @parser_args = if [TrueClass, FalseClass, NilClass].include?(@klass)
          ["-#{@abbrev}", "--[no-]#{@opt_name}", @desc]
        else
          ["-#{@abbrev}", "--#{@opt_name} VALUE", @klass, @desc]
        end
      end

      private

      def parse_name_values(name, custom_abbrev)
        [ (processed_name = name.to_s.strip.downcase).gsub("_", "-"),
          custom_abbrev || processed_name.gsub(/[^a-z]/, "").chars.first || "a"
        ]
      end
      def gvalinfo(v); v.kind_of?(Class) ? [nil,v] : [v,v.class]; end
    end
  end

  # ALintRunner

  def self.clirb
    @clirb ||= CLIRB.new do
      option "changed_only", "only run source files with changes", {
        abbrev: "c"
      }
      option "changed_ref", "reference for changes, use with `-c` opt", {
        abbrev: "r", value: ""
      }
      option "dry_run", "output each linter command to $stdout without executing"
      option "list", "list source files on $stdout", {
        abbrev: "l"
      }
      # show specified source files, cli err backtraces, etc
      option "debug", "run in debug mode", {
        abbrev: "d"
      }
    end
  end

  def self.config
    @config ||= Config.new
  end

  def self.apply(argv)
    clirb.parse!(argv)
    config.apply(clirb.opts)
  end

  def self.bench(*args, &block)
    config.bench(*args, &block)
  end

  def self.run
    begin
      bench("ARGV parse and configure"){ apply(ARGV) }
      Runner.new(self.clirb.args, config: self.config).run
    rescue CLIRB::HelpExit
      config.puts help_msg
    rescue CLIRB::VersionExit
      config.puts config.version
    rescue CLIRB::Error => exception
      config.puts "#{exception.message}\n\n"
      config.puts config.debug ? exception.backtrace.join("\n") : help_msg
      exit(1)
    rescue StandardError => exception
      config.puts "#{exception.class}: #{exception.message}"
      config.puts exception.backtrace.join("\n")
      exit(1)
    end
    exit(0)
  end

  def self.help_msg
    "Usage: #{config.bin_name} [options] [FILES]\n\n"\
    "Options:"\
    "#{clirb}"
  end
end

unless ENV["A_LINT_RUNNER_DISABLE_RUN"]
  ALintRunner.run
end
