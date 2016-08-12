require 'stash/indexer'
require 'stash_ezid/client'
require 'dash2/migrator/id_mode'

module Dash2
  module Migrator

    class Dash2IndexConfig < Stash::Indexer::IndexConfig
      adapter 'Dash2'

      attr_reader :id_mode
      attr_reader :tenant_path

      # Creates a new {Dash2IndexConfig}
      # @param db_config_path [String] the path to the database configuration file
      def initialize(db_config_path:, id_mode:, tenant_path:)
        super(url: URI.join('file:///', File.absolute_path(db_config_path)))
        @id_mode = IDMode.find_by_value(id_mode) || fail("Unknown id_mode: #{id_mode || 'nil'}")
        @tenant_path = tenant_path
      end

      def ezid_config
        @ezid_config ||= tenant_config[:identifier_service]
      end

      def tenant_config
        @tenant_config ||= begin
          tenant_config = YAML.load_file(tenant_path)
          tenant_config[env_name.to_s]
        end
      end

      def db_config_path
        uri.path
      end

      # @param metadata_mapper [Stash::Indexer::MetadataMapper] the metadata mapper
      def create_indexer(metadata_mapper)
        ezid_client = StashEzid::Client.new(ezid_config)
        Dash2Indexer.new(
            metadata_mapper: metadata_mapper,
            db_config_path: db_config_path,
            id_mode: id_mode,
            ezid_client: ezid_client
        )
      end
    end
  end
end
