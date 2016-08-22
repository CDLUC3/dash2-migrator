require 'active_support'
require 'logger'
require 'dash2/migrator/initializers/licenses'
require 'dash2/migrator/initializers/hash_to_ostruct'

module StashDatacite
  @@resource_class = 'StashEngine::Resource' # rubocop:disable Style/ClassVars
end

module Dash2
  module Migrator
    def self.require_gem(gem)
      require(gem)
      gempath = Gem::Specification.find_by_name(gem).gem_dir
      %W(#{gempath}/app/models/#{gem} #{gempath}/lib/#{gem}).each do |path|
        Dir.glob("#{path}/**/*.rb").sort.each(&method(:require))
      end
    end

    require_gem 'stash_engine'
    require_gem 'stash_datacite'
  end
end
