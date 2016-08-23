require 'active_support'
require 'logger'

module Dash2
  module Migrator
    Dir.glob(File.expand_path('../migrator/*.rb', __FILE__)).sort.each(&method(:require))

    def self.production?
      stash_env = ENV['STASH_ENV']
      stash_env && stash_env.casecmp('production').zero?
    end
  end
end
