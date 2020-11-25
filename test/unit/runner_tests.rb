require "assert"

require "a-lint-runner"

class ALintRunner::Runner
  class UnitTests < Assert::Context
    desc "ALintRunner::Runner"
    setup do
      @unit_class = ALintRunner::Runner
    end
    subject{ @unit_class }
  end

  class InitSetupTests < UnitTests
    desc "when init"
    setup do
      Assert.stub(Dir, :pwd){ TEST_SUPPORT_PATH }
      @source_files = [
        "app/file1.rb",
        "app/file2.js",
        "app/file3.scss"
      ]

      @file_paths  = [""]
      @lint_output = ""
      @config      = ALintRunner::Config.new(StringIO.new(@lint_output))
      Assert.stub(ALintRunner, :config){ @config }
    end
    subject{ @runner }
  end

  class InitTests < InitSetupTests
    setup do
      @runner = @unit_class.new(@file_paths, config: @config)
    end

    should have_readers :file_paths, :config

    should "know its attributes" do
      assert_that(subject.file_paths).equals(@file_paths)
      assert_that(subject.config).is_the_same_as(@config)
      assert_that(subject.execute?).is_true
      assert_that(subject.any_source_files?).is_true
      assert_that(subject.any_linters?).is_true
      assert_that(subject.dry_run?).is_false
      assert_that(subject.list?).is_false
      assert_that(subject.debug?).is_false
      assert_that(subject.changed_only?).is_false
      assert_that(subject.linters).equals(@config.linters)
      assert_that(subject.source_files).is_not_empty

      assert_that(subject.cmd_str).equals(
        subject.linters
          .map { |linter| linter.cmd_str(subject.source_files) }
          .join(@unit_class::LINTER_CMD_SEPARATOR)
      )
    end
  end

  class DryRunTests < InitSetupTests
    desc "and configured to dry run"
    setup do
      Assert.stub(@config, :dry_run){ true }

      @runner = @unit_class.new(@file_paths, config: @config)
    end

    should "output the cmd str to stdout and but not execute it" do
      assert_that(subject.execute?).is_false
      assert_that(subject.dry_run?).is_true

      subject.run
      assert_that(@lint_output).includes(subject.cmd_str)
    end
  end

  class ListTests < InitSetupTests
    desc "and configured to list"
    setup do
      Assert.stub(@config, :list){ true }

      @runner = @unit_class.new(@file_paths, config: @config)
    end

    should "list out the lint files to stdout and not execute the cmd str" do
      assert_that(subject.execute?).is_false
      assert_that(subject.list?).is_true

      subject.run
      assert_that(@lint_output).includes(subject.source_files.join("\n"))
    end
  end

  class ChangedOnlySetupTests < InitSetupTests
    setup do
      @changed_ref = Factory.string
      Assert.stub(@config, :changed_ref){ @changed_ref }
      Assert.stub(@config, :changed_only){ true }
      Assert.stub(@config, :dry_run){ true }

      @changed_source_file = @source_files.sample
      @git_cmd_used = nil
      Assert.stub(ALintRunner::GitChangedFiles, :new) do |*args|
        @git_cmd_used = ALintRunner::GitChangedFiles.cmd(*args)
        ALintRunner::ChangedResult.new(@git_cmd_used, [@changed_source_file])
      end

      @file_paths = @source_files
    end
  end

  class ChangedOnlyTests < ChangedOnlySetupTests
    desc "and configured in changed only mode"
    setup do
      @runner = @unit_class.new(@file_paths, config: @config)
    end

    should "only run the source files that have changed" do
      assert_that(subject.changed_only?).is_true
      assert_that(subject.source_files).equals([@changed_source_file])

      assert_that(@git_cmd_used).equals(
        "git diff --no-ext-diff --name-only #{@changed_ref} "\
        "-- #{@file_paths.join(" ")} && "\
        "git ls-files --others --exclude-standard "\
        "-- #{@file_paths.join(" ")}"
      )
    end
  end

  class DebugTests < ChangedOnlySetupTests
    desc "and configured in debug mode"
    setup do
      Assert.stub(@config, :debug){ true }

      @runner = @unit_class.new(@file_paths, config: @config)
    end

    should "output detailed debug info" do
      changed_result = ALintRunner::GitChangedFiles.new(@config, @file_paths)
      changed_cmd = changed_result.cmd
      changed_files_count = changed_result.files.size
      changed_files_lines = changed_result.files.map{ |f| "[DEBUG]   #{f}" }

      assert_that(subject.execute?).is_false

      subject.run
      assert_that(@lint_output).includes("[DEBUG] Lookup changed source files...")
      assert_that(@lint_output).includes(
        "[DEBUG]   `#{changed_cmd}`\n"\
        "[DEBUG] #{changed_files_count} source files:\n"\
        "#{changed_files_lines.join("\n")}\n"\
        "[DEBUG] Lint command:\n"\
        "[DEBUG]   #{subject.cmd_str}\n"
      )
    end
  end
end
