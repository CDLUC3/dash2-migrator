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

      gempath = gem_path(gem)
      ["#{gempath}/app/models/#{gem}", "#{gempath}/lib/#{gem}"].each do |path|
        Dir.glob("#{path}/**/*.rb").sort.each(&method(:require))
      end

      if 'stash_engine' == gem
        require "#{gempath}/config/initializers/hash_to_ostruct.rb"
      end

    end

    StashDatacite::ResourcePatch.associate_with_resource(StashEngine::Resource)

    # ###################################################

    # "Indexes" records by writing them into the stash_engine / stash_datacite database
    class Dash2Indexer < Stash::Indexer::Indexer

      attr_reader :id_mode
      attr_reader :tenant_config
      attr_reader :db_config_path

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
        ensure_db_connection!
        Stash::Harvester.log.info("Indexing records for tenant_id #{tenant.tenant_id} into database #{db_config['database']} on #{db_config['host']}")
        harvested_records.each do |hr|
          ActiveRecord::Base.transaction(requires_new: true) do
            index_record(hr.as_wrapper, hr.user_uid)
          end
        end
      end

      def index_record(stash_wrapper, user_uid)
        original_doi = stash_wrapper.identifier.value
        begin
          Stash::Harvester.log.info("Importing #{stash_wrapper.id_value} for user #{user_uid}, tenant_id #{tenant.tenant_id}")
          importer = Dash2::Migrator::Importer.new(
              stash_wrapper: stash_wrapper,
              user_uid: user_uid,
              ezid_client: ezid_client,
              id_mode: id_mode,
              tenant: tenant
          )
          importer.import
        rescue => e
          Stash::Harvester.log.error("Import failed for #{stash_wrapper.id_value} for user #{user_uid}, tenant_id #{tenant.tenant_id}: #{e}")
          Stash::Harvester.log.error(e.backtrace.join("\n")) if e.backtrace

          problem_file = "spec/data/problem-files/stash-wrapper-#{original_doi.gsub('/', '-')}.xml"
          stash_wrapper.write_to_file(problem_file)
          Stash::Harvester.log.debug("Wrote problem stash-wrapper to #{problem_file}")
        end
      end

      def db_config
        @db_config ||= begin
          stash_env = ENV['STASH_ENV']
          raise '$STASH_ENV not set' unless stash_env
          YAML.load_file(db_config_path)[stash_env]
        end
      end

      def ensure_db_connection!
        ActiveRecord::Base.connection
      rescue ActiveRecord::ConnectionNotEstablished
        ActiveRecord::Base.establish_connection(db_config)
      end

    end
  end
end