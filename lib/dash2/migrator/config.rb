require 'config/factory'
require 'stash/indexer'

module Dash2
  module Migrator
    class Config

      # The index configuration
      # @return [IndexConfig] the configuration (as an apporpriate
      #   subclass of `IndexConfig` for the specified adapter)
      attr_reader :index_config

      # The metadata mapper
      # @return [MetadataMapper] the mapper (as an appropriate
      #   subclass of `MetadataMapper` for the specified mapping)
      attr_reader :metadata_mapper

      def initialize(index_config:, metadata_mapper:)
        @index_config = index_config
        @metadata_mapper = metadata_mapper
      end

      # Reads the specified file and creates a new `Config` from it.
      #
      # @param path [String] the path to read the YAML from
      # @raise [IOError] in the event the file does not exist, cannot be read, or is invalid
      def self.from_file(path)
        validate_path(path)
        begin
          env = load_env(path)
          from_env(env)
        rescue IOError
          raise
        rescue => e
          warn(e)
          warn(e.backtrace.join("\n")) if e.backtrace
          raise IOError, "Error parsing specified config file #{path}: #{e.message}"
        end
      end

      # Private ###########################################

      def self.from_env(env)
        index_config = Stash::Indexer::IndexConfig.for_environment(env, :index)
        metadata_mapper = Stash::Indexer::MetadataMapper.for_environment(env, :mapper)
        Config.new(index_config: index_config, metadata_mapper: metadata_mapper)
      end
      private_class_method :from_env

      # TODO: clean up this code and/or make Environments smarter
      def self.load_env(path)
        env_name = ENV['STASH_ENV'] || ::Config::Factory::Environments::DEFAULT_ENVIRONMENT
        env_name = env_name.to_s.downcase.to_sym
        envs = ::Config::Factory::Environments.load_file(path)

        # Fall back to parsing as single-environment config file if we have to
        envs[env_name] || ::Config::Factory::Environment.load_file(path)
      end
      private_class_method :load_env

      def self.validate_path(path)
        raise IOError, "Specified config file #{path} does not exist" unless File.exist?(path)
        raise IOError, "Specified config file #{path} is not a file" unless File.file?(path)
        raise IOError, "Specified config file #{path} is not readable" unless File.readable?(path)
      end

      private_class_method :validate_path
    end
  end
end
