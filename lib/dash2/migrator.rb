require 'active_support'
require 'logger'
require 'stash/harvester'
require 'stash/wrapper/stash_wrapper_extensions'

module Dash2
  module Migrator

    Dir.glob(File.expand_path('../migrator/*.rb', __FILE__)).sort.each(&method(:require))

    def self.production?
      stash_env = ENV['STASH_ENV']
      stash_env && stash_env.casecmp('production').zero?
    end

    def self.log
      Stash::Harvester.log
    end
  end
end
