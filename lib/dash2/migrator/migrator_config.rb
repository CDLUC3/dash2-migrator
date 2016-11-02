require 'stash/config'
require 'dash2/migrator/harvester/merritt_atom_source_config'
require 'dash2/migrator/indexer/index_config'

module Dash2
  module Migrator
    # TODO: Rename this to MigrationJobConfig or similar
    class MigratorConfig < Stash::Config

      MerrittAtomSourceConfig = Harvester::MerrittAtomSourceConfig
      IndexerIndexConfig = Indexer::IndexConfig
      Environment = Config::Factory::Environment

      def initialize(source_config:, index_config:)
        super(
          source_config: MigratorConfig.source_config(source_config),
          index_config: MigratorConfig.index_config(index_config),
          persistence_config: nil,
          metadata_mapper: nil
        )
      end

      def persistence_config
        @persistence_config ||= Stash::NoOpPersistenceConfig.new
      end

      def self.source_config(source_config)
        return source_config if source_config.is_a?(MerrittAtomSourceConfig)
        return source_config if source_config.to_s =~ /InstanceDouble\(#{MerrittAtomSourceConfig}\)/ # For RSpec tests
        raise ArgumentError, "source_config does not appear to be a #{MerrittAtomSourceConfig}: #{source_config}" unless source_config.is_a?(MerrittAtomSourceConfig)
      end

      def self.index_config(index_config)
        return index_config if index_config.is_a?(IndexerIndexConfig)
        return index_config if index_config.to_s =~ /InstanceDouble\(#{IndexerIndexConfig}\)/ # For RSpec tests
        raise ArgumentError, "index_config does not appear to be a #{IndexerIndexConfig}: #{index_config}" unless index_config.is_a?(IndexerIndexConfig)
      end

      def self.from_env(env)
        users_path = env.args_for(:users_path)
        user_provider = Dash2::Migrator::Harvester::UserProvider.new(users_path)
        [:source, :index].each do |conf|
          args = env.args_for(conf)
          args[:user_provider] = user_provider
        end

        source_config = Stash::Harvester::SourceConfig.for_environment(env, :source)
        index_config = Stash::Indexer::IndexConfig.for_environment(env, :index)
        MigratorConfig.new(source_config: source_config, index_config: index_config)
      end
    end
  end
end
