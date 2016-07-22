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

      def create_harvest_task(from_time=nil, until_time=nil)
        MerrittAtomHarvestTask.new(config: self, from_time: from_time, until_time: until_time)
      end

    end
  end
end
