require 'stash/harvester/source_config'

module Dash2
  module Migrator
    class MerrittAtomSourceConfig < Stash::Harvester::SourceConfig
      protocol 'Merritt Atom'

      attr_reader :tenant_path

      def initialize(tenant_path:, feed_uri:)
        super(source_url: feed_uri)
        @tenant_path = File.absolute_path(tenant_path)
      end

      def feed_uri
        source_uri
      end

    end
  end
end
