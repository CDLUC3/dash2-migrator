require 'stash/indexer'

module Dash2
  module Migrator
    class Dash2IndexConfig < Stash::Indexer::IndexConfig
      adapter 'Dash2'

      # Creates a new {Dash2IndexConfig}
      # @param db_config_path [String] the path to the database configuration file
      def initialize(db_config_path:)
        super(url: URI.join('file:///', File.absolute_path(db_config_path)))
      end

      def db_config_path
        uri.path
      end

      # @param metadata_mapper [Stash::Indexer::MetadataMapper] the metadata mapper
      def create_indexer(metadata_mapper)
        Dash2Indexer.new(metadata_mapper: metadata_mapper, db_config_path: db_config_path)
      end
    end
  end
end
