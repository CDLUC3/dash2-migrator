require 'logger'
require 'stash/harvester'

module Dash2
  module Reversioning
    Dir.glob(File.expand_path('../reversioning/*.rb', __FILE__)).sort.each(&method(:require))

    def self.production?
      env_name && env_name.casecmp('production').zero?
    end

    def self.stage?
      env_name && env_name.casecmp('stage').zero?
    end

    def self.env_name
      ENV['STASH_ENV']
    end

    def self.log
      Stash::Harvester.log
    end

    def self.dry_run?
      true
    end
  end
end
