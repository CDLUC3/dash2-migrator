require 'rss'
require 'stash/harvester'

module Dash2
  module Migrator
    module Harvester
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
          # options = {username: config.username, password: config.password}
          pages = enum_for(:pages, query_uri, parse_rss(query_uri)).lazy
          pages.flat_map(&:items).map do |entry|
            MerrittAtomHarvestedRecord.new(query_uri, entry)
          end
        end

        private

        def parse_rss(uri)
          # RSS::Parser.parse() isn't smart enough to handle authenticated URIs
          # (blows up in https://github.com/ruby/ruby/blob/v2_2_3/lib/open-uri.rb#L260-L262)
          feed_xml = RestClient.get(uri.to_s)
          RSS::Parser.parse(feed_xml, false)
        end

        def pages(feed_uri, feed)
          page_uri = feed_uri
          page = feed
          loop do
            yield page
            self_uri, next_uri, last_uri = links_for(page)
            break if self_uri == last_uri
            page_uri = next_uri.relative? ? page_uri + next_uri : next_uri
            page = parse_rss(page_uri)
          end
        end

        def links_for(feed)
          %w(self next last).map do |rel|
            link = feed.links.find { |l| l.rel == rel }
            URI(link.href) if link
          end
        end
      end
    end
  end
end
