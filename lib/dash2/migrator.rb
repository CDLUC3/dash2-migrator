require 'active_support'
require 'logger'
require 'stash/harvester'
require 'stash/wrapper/stash_wrapper_extensions'

module Dash2
  module Migrator

    Dir.glob(File.expand_path('../migrator/*.rb', __FILE__)).sort.each(&method(:require))

    def self.production?
      env_name && env_name.casecmp('production').zero?
    end

    def self.env_name
      ENV['STASH_ENV']
    end

    def self.log
      Stash::Harvester.log
    end

    # TODO: sort out name collisions
    class Migrationator
      MerrittAtomSourceConfig = Harvester::MerrittAtomSourceConfig
      IndexerIndexConfig = Indexer::IndexConfig
      HarvesterApp = Stash::HarvesterApp::Application

      attr_reader :sources
      attr_reader :index_db_config_path
      attr_reader :index_tenant_override
      attr_reader :env_name

      def initialize(sources:, index_db_config_path:, index_tenant_override: nil, env_name: Dash2::Migrator.env_name)
        Migrator.log.info("Initializing migrator with DB #{index_db_config_path} in environment #{env_name}")
        @sources = sources
        @index_db_config_path = index_db_config_path
        @index_tenant_override = index_tenant_override
        @env_name = env_name
      end

      def migrate!
        sources.each do |source|
          app = create_app_instance(source[:tenant_path], source[:feed_uri])
          app.start
        end
      end

      def create_app_instance(tenant_path, feed_uri)
        index_tenant_path = index_tenant_override || tenant_path
        source_config = MerrittAtomSourceConfig.new(tenant_path: tenant_path, feed_uri: feed_uri, env_name: env_name)
        index_config = IndexerIndexConfig.new(db_config_path: index_db_config_path, tenant_path: index_tenant_path)
        migrator_config = MigratorConfig.new(source_config: source_config, index_config: index_config)
        HarvesterApp.with_config(migrator_config)
      end

      def self.from_file(config_path)
        config = deep_symbolize_keys(YAML.load_file(config_path))
        index_config = config[:index]
        Migrationator.new(
          sources: config[:sources],
          index_db_config_path: index_config[:db_config_path],
          index_tenant_override: index_config[:tenant_override]
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
