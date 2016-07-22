require 'rss'
require 'stash/harvester'

module Dash2
  module Migrator
    class MerrittAtomHarvestedRecord < Stash::Harvester::HarvestedRecord

      attr_reader :entry

      def initialize(entry)
        super(identifier: entry.id.content, timestamp: entry.updated)
        @entry = entry
      end

    end
  end
end
