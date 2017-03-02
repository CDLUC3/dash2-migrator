require 'active_support'
require 'stash/wrapper/stash_wrapper_extensions'
require 'stash/harvester_app'

module Dash2
  module Migrator
    class MigrationJob
      MerrittAtomSourceConfig = Harvester::MerrittAtomSourceConfig
      IndexerIndexConfig = Indexer::IndexConfig
      HarvesterApp = Stash::HarvesterApp::Application

      attr_reader :sources
      attr_reader :index_db_config_path
      attr_reader :index_tenant_override
      attr_reader :env_name
      attr_reader :users_path

      def initialize(sources:, index_db_config_path:, index_tenant_override: nil, users_path:, env_name: Dash2::Migrator.env_name)
        Migrator.log.info("Initializing migrator with DB #{index_db_config_path}, users #{users_path} in environment #{env_name}")
        @sources = sources
        @index_db_config_path = index_db_config_path
        @index_tenant_override = index_tenant_override
        @env_name = env_name
        @users_path = users_path
      end

      def migrate!
        sources.each do |source|
          app = create_app(source)
          app.start
        end
      end

      def create_app(source)
        users_abs_path = File.absolute_path(users_path)
        user_provider = Dash2::Migrator::Harvester::UserProvider.new(users_abs_path)

        tenant_path = source[:tenant_path]
        feed_uri = source[:feed_uri]

        index_tenant_path = index_tenant_override || tenant_path
        source_config = MerrittAtomSourceConfig.new(tenant_path: tenant_path, feed_uri: feed_uri, user_provider: user_provider, env_name: env_name)
        index_config = IndexerIndexConfig.new(db_config_path: index_db_config_path, user_provider: user_provider, tenant_path: index_tenant_path)
        migrator_config = MigratorConfig.new(source_config: source_config, index_config: index_config)
        HarvesterApp.with_config(migrator_config)
      end

      def self.from_file(config_path)
        config = deep_symbolize_keys(YAML.load_file(config_path))
        index_config = config[:index]
        users_path = config[:users_path]
        MigrationJob.new(
          sources: config[:sources],
          index_db_config_path: index_config[:db_config_path],
          index_tenant_override: index_config[:tenant_override],
          users_path: users_path
        )
      end

      def self.deep_symbolize_keys(val)
        if val.is_a?(Hash)
          val.map do |k, v|
            [k.respond_to?(:to_sym) ? k.to_sym : k, deep_symbolize_keys(v)]
          end.to_h
        elsif val.is_a?(Array)
          val.collect! { |x| deep_symbolize_keys(x) }
        else
          val
        end
      end
    end
  end
end
