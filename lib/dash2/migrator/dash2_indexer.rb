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
      attr_reader :tenant_config

      # Creates a new {Dash2Indexer}
      # @param metadata_mapper [Stash::Indexer::MetadataMapper] the metadata mapper
      # @param db_config_path [String] the path to the database configuration file
      def initialize(metadata_mapper:, db_config_path:, id_mode:, tenant_config:)
        super(metadata_mapper: metadata_mapper)
        @db_config_path = db_config_path
        @id_mode = id_mode
        @tenant_config = tenant_config
      end

      def ezid_config
        @ezid_config ||= tenant_config[:identifier_service]
      end

      def ezid_client
        @ezid_client ||= StashEzid::Client.new(ezid_config)
      end

      def tenant
        @tenant ||= StashEngine::Tenant.new(tenant_config)
      end

      def index(harvested_records)
        harvested_records.each do |hr|
          hr.each do |r|
            index_record(r.as_wrapper, r.user_uid)
          end
        end
      end

      def index_record(stash_wrapper, user_uid)
        importer = Dash2::Migrator::Importer.new(
            stash_wrapper: stash_wrapper,
            user_uid: user_uid,
            ezid_client: ezid_client,
            id_mode: id_mode,
            tenant: tenant,
        )
        importer.import
      end

    end
  end
end
