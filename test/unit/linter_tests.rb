require "assert"

require "a-lint-runner"

class ALintRunner::Linter
  class UnitTests < Assert::Context
    desc "ALintRunner::Linter"
    setup do
      @unit_class = ALintRunner::Linter
    end
    subject { @unit_class }
  end

  class InitTests < UnitTests
    desc "when init"
    subject {
      @unit_class.new(
        name: name1,
        executable: executable1,
        extensions: [extension1]
      )
    }

    let(:name1) { Factory.string }
    let(:executable1) { Factory.string }
    let(:extension1) { ".rb" }
    let(:applicable_source_files) { ["app/file1.rb", "app/file2.rb"] }
    let(:not_applicable_source_file) { "app/file2.js" }

    should "know its attributes" do
      assert_that(subject.name).equals(name1)
      assert_that(subject.executable).equals(executable1)
      assert_that(subject.extensions).equals([extension1])
    end

    should "know its cmd_str given applicable source files" do
      assert_that(subject.cmd_str(applicable_source_files)).equals(
        "#{executable1} #{applicable_source_files.join(" ")}"
      )
    end

    should "know its cmd_str given not applicable source files" do
      assert_that(subject.cmd_str([not_applicable_source_file])).is_nil
    end
  end
end
