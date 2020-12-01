require "assert"

require "a-lint-runner"

class ALintRunner::Config
  class UnitTests < Assert::Context
    desc "ALintRunner::Config"
    setup do
      @unit_class = ALintRunner::Config
    end
    subject{ @unit_class }

    should have_imeths :settings
  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @config = @unit_class.new
    end
    subject{ @config }

    should have_readers :stdout, :bin_name, :version
    should have_imeths  :changed_only, :changed_ref, :dry_run, :list, :debug
    should have_imeths  :linters, :apply
    should have_imeths :debug_msg, :debug_puts, :puts, :print
    should have_imeths :bench, :bench_start_msg, :bench_finish_msg

    should "know its stdout" do
      assert_that(subject.stdout).is_the_same_as($stdout)

      io = StringIO.new("")
      assert_that(@unit_class.new(io).stdout).is_the_same_as(io)
    end

    should "know its CONTANT driven attrs" do
      assert_that(subject.bin_name).equals(ALintRunner::BIN_NAME)
      assert_that(subject.version).equals(ALintRunner::VERSION)
    end

    should "default its settings attrs" do
      assert_that(subject.changed_only).is_false
      assert_that(subject.changed_ref).is_empty
      assert_that(subject.dry_run).is_false
      assert_that(subject.list).is_false
      assert_that(subject.debug).is_false
    end

    should "allow applying custom settings attrs" do
      settings = {
        :changed_only => true,
        :changed_ref  => Factory.string,
        :dry_run      => true,
        :list         => true,
        :debug        => true
      }
      subject.apply(settings)

      assert_that(subject.changed_only).equals(settings[:changed_only])
      assert_that(subject.changed_ref).equals(settings[:changed_ref])
      assert_that(subject.dry_run).equals(settings[:dry_run])
      assert_that(subject.list).equals(settings[:list])
      assert_that(subject.debug).equals(settings[:debug])
    end

    should "know how to build debug messages" do
      msg = Factory.string
      assert_that(subject.debug_msg(msg)).equals("[DEBUG] #{msg}")
    end

    should "know how to build bench start messages" do
      msg = Factory.string
      assert_that(subject.bench_start_msg(msg))
        .equals(subject.debug_msg("#{msg}...".ljust(30)))

      msg = Factory.string(35)
      assert_that(subject.bench_start_msg(msg)).equals(
        subject.debug_msg("#{msg}...".ljust(30)))
    end

    should "know how to build bench finish messages" do
      time_in_ms = Factory.float
      assert_that(subject.bench_finish_msg(time_in_ms)).equals(
        " (#{time_in_ms} ms)")
    end
  end

  class BenchTests < InitTests
    desc "`bench`"
    setup do
      @start_msg = Factory.string
      @proc      = proc{}

      @lint_output = ""
      lint_stdout  = StringIO.new(@lint_output)

      @config = @unit_class.new(lint_stdout)
    end

    should "not output any stdout info if not in debug mode" do
      Assert.stub(subject, :debug){ false }
      subject.bench(@start_msg, &@proc)

      assert_that(@lint_output).is_empty
    end

    should "output any stdout info if in debug mode" do
      Assert.stub(subject, :debug){ true }
      time_in_ms = subject.bench(@start_msg, &@proc)

      assert_that(@lint_output).equals(
        "#{subject.bench_start_msg(@start_msg)}"\
        "#{subject.bench_finish_msg(time_in_ms)}\n"
      )
    end
  end
end
