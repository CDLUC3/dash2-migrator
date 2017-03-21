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
    add_filter '/lib/stash_datacite/'
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
ENV['RAILS_ENV'] = 'test'

require 'stash_engine'

# TODO: simplify / standardize this
stash_engine_path = Gem::Specification.find_by_name('stash_engine').gem_dir
require "#{stash_engine_path}/config/initializers/hash_to_ostruct.rb"
require "#{stash_engine_path}/config/initializers/repository.rb"
require "#{stash_engine_path}/config/initializers/inflections.rb"

# TODO: MockRails.application.root and use stash_engine/config/initializers/licenses.rb
::LICENSES = YAML.load_file('config/licenses.yml').with_indifferent_access
# TODO: as above, but also move /config/initializers/app_config.rb from dash2 into stash_engine
# ::APP_CONFIG = OpenStruct.new(YAML.load_file('config/app_config.yml')['test'])

# Note: Even if we're not doing any database work, ActiveRecord callbacks will still raise warnings
ActiveRecord::Base.raise_in_transactional_callbacks = true

%w(
  app/models/stash_engine
  lib/stash_engine
).each do |dir|
  Dir.glob("#{stash_engine_path}/#{dir}/**/*.rb").sort.each(&method(:require))
end

require 'dash2/migrator'
require 'dash2/reversioning'
require 'stash/config'
