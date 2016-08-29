require 'stash/indexer'
require 'stash_ezid/client'

module Dash2
  module Migrator
    class IndexConfig < Stash::Indexer::IndexConfig
      adapter 'Dash2'

      attr_reader :tenant_path

      def initialize(db_config_path:, tenant_path:)
        super(url: URI.join('file:///', File.absolute_path(db_config_path)))
        @tenant_path = File.absolute_path(tenant_path)
      end

      def description
        @desc ||= begin
          desc = "#{self.class}: #{tenant_path} -> #{db_config_path}"
          desc << ' (production)' if Migrator.production?
          desc
        end
      end

      def db_config_path
        uri.path
      end

      def tenant_config
        @tenant_config ||= begin
          full_tenant_config = YAML.load_file(tenant_path)
          env_tenant_config = full_tenant_config[env_name.to_s]
          deep_symbolize_keys(env_tenant_config)
        end
      end

      def create_indexer
        Indexer.new(tenant_config: tenant_config)
      end

      private

      def deep_symbolize_keys(val)
        return val unless val.is_a?(Hash)
        val.map do |k, v|
          [k.respond_to?(:to_sym) ? k.to_sym : k, deep_symbolize_keys(v)]
        end.to_h
      end
    end
  end
end
