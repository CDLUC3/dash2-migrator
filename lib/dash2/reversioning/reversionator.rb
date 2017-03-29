require 'dash2/migrator'

module Dash2
  module Reversioning
    class Reversionator
      attr_reader :tenant_path
      attr_reader :feed_uri

      def initialize(tenant_path:, feed_uri:)
        @tenant_path = tenant_path
        @feed_uri = feed_uri
      end

      def self.log
        Dash2::Reversioning.log
      end

      def log
        Dash2::Reversioning.log
      end

      def config
        @config ||= Dash2::Migrator::Harvester::MerrittAtomSourceConfig.new(
          tenant_path: tenant_path,
          feed_uri: feed_uri,
          user_provider: nil,
          env_name: Dash2::Reversioning.env_name
        )
      end

      def update!
        harvest_task = Dash2::Migrator::Harvester::MerrittAtomHarvestTask.new(config: config)
        harvest_task.harvest_records.each do |record|
          ark = record.ark
          next unless ark

          log.warn("Unable to determine Merritt version record #{ark} (doi:#{record.doi}); stash-wrapper.xml missing?") unless record.stash_version
          next unless record.stash_version

          Updater.from_record(record).update!
        end
      end
    end
  end
end
