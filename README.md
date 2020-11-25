# a-lint-runner.rb

This is a CLI that generates and executes ruby linter commands.  Copy/rename it into your $PATH and customize the CONSTANT values at the top of the script for your linter setup.

## Features

* A common, friendly CLI for running linters, regardless of the linter tools/framework you use
* Run only the files that have been updated/changed (using Git)
* Specify source files/directories with absolute or relative paths
* Debug and dry-run options to help debug your configuration/setup

## Usage

This assumes a `BIN_NAME` of `runlints` (see the Installation section below).

```
$ runlints -h
Usage: runlints [options] [FILES]

Options:
    -c, --[no-]changed-only          only lint source files with changes
    -r, --changed-ref VALUE          reference for changes, use with `-c` opt
        --[no-]dry-run               output each linter command to $stdout without executing
    -l, --[no-]list                  list source files on $stdout
    -d, --[no-]debug                 run in debug mode
        --version
        --help
$ cd my/ruby/project
$ runlints
```

### Options

Given these CONSTANT values:

```ruby
BIN_NAME = "runlints"
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
```

#### Debug Mode

```
$ runlints -d
[DEBUG] CLI init and parse...          (6.686 ms)
[DEBUG] 0 specified source files:
Running Rubocop
[DEBUG]   rubocop .


Running ES Lint
[DEBUG]   ./node_modules/.bin/eslint .


Running SCSS Lint
[DEBUG]   scss-lint .
```

This option, in addition to executing the linter command, outputs a bunch of detailed debug information.

#### Changed Only

```
$ runlints -d -c
[DEBUG] CLI init and parse...            (7.138 ms)
[DEBUG] Lookup changed source files...   (24.889 ms)
[DEBUG]   `git diff --no-ext-diff --name-only  -- . && git ls-files --others --exclude-standard -- .`
[DEBUG] 1 specified source files:
[DEBUG]   app/file1.rb
Running Rubocop
[DEBUG]   rubocop app/file1.rb


Running ES Lint


Running SCSS Lint
```

This runs a git command to determine which files have been updated (relative to `HEAD` by default) and only run the linters on those files.

You can specify a custom git ref to use instead:

```
$ runlints -d -c -r master
[DEBUG] CLI init and parse...            (6.933 ms)
[DEBUG] Lookup changed source files...   (162.297 ms)
[DEBUG]   `git diff --no-ext-diff --name-only master -- . && git ls-files --others --exclude-standard -- .`
[DEBUG] 2 specified source files:
[DEBUG]   app/file2.js
[DEBUG]   app/file3.scss


Running ES Lint
[DEBUG]   ./node_modules/.bin/eslint app/file2.js


Running SCSS Lint
[DEBUG]   scss-lint app/file3.scss
```

#### Dry-Run

```
$ runlints --dry-run
Running Rubocop
rubocop .


Running ES Lint
./node_modules/.bin/eslint .


Running SCSS Lint
scss-lint .
```

This option only outputs the linter command it would have run. It does not execute the linter command.

#### List

```
$ runlints -l
app/file1.rb
app/file2.js
app/file3.scss
```

This option, similar to `--dry-run`, does not execute any linter command. It lists out each source file it would execute to `$stdout`.

## Installation

**Tip**: repeat these steps to install multiple different lint runners where the CONSTANT settings need to be different (be sure to use distinct `BIN_NAME`s).

1. Copy `a-lint-runner.rb` to some folder in your `$PATH` (ie `$HOME/.bin`)
2. Rename it to something you like.  For example: `mv a-lint-runner.rb runlints`.
3. Make it executable: `chmod 755 runlints`
4. Update the default CONSTANTS as needed for your lint setup:

```ruby
# in the runner script file...

# ...

module ALintRunner
  VERSION = "x.x.x"

  # update these as needed for your lint setup
  BIN_NAME = "runlints" # should match what you name the executable
  LINTERS =
    [
      {
        name: "Rubocop",
        executable: "rubocop"
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

# ...
```

### Try it out

```
$ runlints -h
Usage: runlints [options] [FILES]

Options:
    -c, --[no-]changed-only          only lint source files with changes
    -r, --changed-ref VALUE          reference for changes, use with `-c` opt
        --[no-]dry-run               output each linter command to $stdout without executing
    -l, --[no-]list                  list source files on $stdout
    -d, --[no-]debug                 run in debug mode
        --version
        --help
$ runlints --debug --dry-run
$ runlints
```
