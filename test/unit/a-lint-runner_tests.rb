require "assert"

require "a-lint-runner"

module ALintRunner
  class UnitTests < Assert::Context
    desc "ALintRunner"
    setup do
      @unit_module = ALintRunner
    end
    subject{ @unit_module }

    should have_imeths :config, :apply, :bench, :run

    should "know its default CONTANTS" do
      assert_that(subject::BIN_NAME).equals("a-lint-runner")
      assert_that(subject::SOURCE_FILES).equals(
        [
          "app", "config", "db", "lib", "script", "test"
        ]
      )
      assert_that(subject::IGNORED_FILES).equals(
        [
          "test/fixtures"
        ]
      )
      assert_that(subject::LINTERS).equals(
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
      )
    end

    should "know its config singleton" do
      assert_that(subject.config).is_an_instance_of(subject::Config)
      assert_that(subject.config).is_the_same_as(subject.config)
    end
  end
end
