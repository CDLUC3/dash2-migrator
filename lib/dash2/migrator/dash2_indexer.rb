require 'active_record'
require 'stash/indexer'
require 'stash_ezid/client'
require 'dash2/migrator/id_mode'

module Dash2
  module Migrator

    # ###################################################
    # Require hacks

    ::LICENSES = YAML.load_file('config/licenses.yml')

    def self.gem_path(gem)
      Gem::Specification.find_by_name(gem).gem_dir
    end

    %w(stash_engine stash_datacite).each do |gem|
      require gem

      if 'stash_datacite' == gem
        StashDatacite.class_variable_set(:@@resource_class, 'StashEngine::Resource')
      end

      model_path = "#{gem_path(gem)}/app/models/#{gem}"
      lib_path = "#{gem_path(gem)}/lib/#{gem}"
      [model_path, lib_path].each do |path|
        Dir.glob("#{path}/**/*.rb").sort.each(&method(:require))
      end
    end

    StashDatacite::ResourcePatch.associate_with_resource(StashEngine::Resource)

    # ###################################################

    # "Indexes" records by writing them into the stash_engine / stash_datacite database
    class Dash2Indexer < Stash::Indexer::Indexer

      attr_reader :id_mode
      attr_reader :ezid_client

      # Creates a new {Dash2Indexer}
      # @param metadata_mapper [Stash::Indexer::MetadataMapper] the metadata mapper
      # @param db_config_path [String] the path to the database configuration file
      def initialize(metadata_mapper:, db_config_path:, id_mode:, ezid_client:)
        super(metadata_mapper: metadata_mapper)
        @db_config_path = db_config_path
        @id_mode = id_mode
        @ezid_client = ezid_client
      end

      def index(harvested_records)
        harvested_records.each do |hr|
          hr.each do |r|
            index_record(r.as_wrapper)
          end
        end
      end

      def index_record(stash_wrapper)
        # TODO: mint or update DOI
        # TODO: fake files for test data
        # TODO: submit to Merritt
      end

    end
  end
end
