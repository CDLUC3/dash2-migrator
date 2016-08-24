# ------------------------------------------------------------
# SimpleCov setup

if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-console'

  # Hack for SimpleCov #5 https://github.com/chetan/simplecov-console/issues/5
  Module::ROOT = Dir.pwd
  SimpleCov::Formatter::Console::ROOT = Dir.pwd

  SimpleCov.command_name 'spec:lib'

  SimpleCov.minimum_coverage 100
  SimpleCov.start do
    add_filter '/spec/'
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console,
    ]
  end
end

# ------------------------------------------------------------
# Rspec configuration

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  config.mock_with :rspec
end

require 'rspec_custom_matchers'

# ------------------------------------------------------------
# Stash

ENV['STASH_ENV'] = 'test'

require 'dash2/migrator'
require 'stash/config'
