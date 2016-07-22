require 'rss'
require 'stash/harvester'

module Dash2
  module Migrator
    class MerrittAtomHarvestTask < Stash::Harvester::HarvestTask

      def initialize(config:, from_time: nil, until_time: nil)
        super(config: config)
        warn("Ignoring from_time #{from_time}") if from_time
        warn("Ignoring until_time #{until_time}") if until_time
      end

      def query_uri
        config.feed_uri
      end

      def harvest_records
        pages = enum_for(:pages, query_uri, RSS::Parser.parse(query_uri, false)).lazy
        pages.flat_map do |f|
          f.items
        end.map do |entry|
          MerrittAtomHarvestedRecord.new(query_uri, entry)
        end
      end

      private

      def pages(feed_uri, feed)
        page_uri = feed_uri
        page = feed
        loop do
          yield page
          self_uri, next_uri, last_uri = links_for(page)
          break if self_uri == last_uri
          page_uri = next_uri.relative? ? page_uri + next_uri : next_uri
          page = RSS::Parser.parse(page_uri, false)
        end
      end

      def links_for(feed)
        %w(self next last).map do |rel|
          link = feed.links.find {|l| l.rel == rel }
          URI(link.href) if link
        end
      end

    end
  end
end
