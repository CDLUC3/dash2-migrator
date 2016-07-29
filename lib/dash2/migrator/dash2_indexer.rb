require 'stash/indexer'

module Dash2
  module Migrator
    # "Indexes" recorsd by writing them into the stash_engine / stash_datacite database
    class Dash2Indexer < Stash::Indexer::Indexer
      # Creates a new {Dash2Indexer}
      # @param metadata_mapper [Stash::Indexer::MetadataMapper] the metadata mapper
      # @param db_config_path [String] the path to the database configuration file
      def initialize(metadata_mapper:, db_config_path:)
        super(metadata_mapper: metadata_mapper)
        @db_config_path = db_config_path
      end
    end

    # Configuration for a {Dash2Indexer}
    class Dash2IndexConfig < Stash::Indexer::IndexConfig
      adapter 'Dash2'

      # Creates a new {Dash2IndexConfig}
      # @param metadata_mapper [Stash::Indexer::MetadataMapper] the metadata mapper
      # @param db_config_path [String] the path to the database configuration file
      def initialize(db_config_path:)
        super(url: URI.join('file:///', File.absolute_path(db_config_path)))
      end

      def db_config_path
        uri.path
      end

      def create_indexer(metadata_mapper)
        Dash2Indexer.new(metadata_mapper: metadata_mapper, db_config_path: db_config_path)
      end
    end
  end
end
