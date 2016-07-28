require 'rss'
require 'rest-client'
require 'stash/harvester'
require 'datacite/mapping'

module Dash2
  module Migrator
    class MerrittAtomHarvestedRecord < Stash::Harvester::HarvestedRecord

      DOI_PATTERN = %r{10\..+/.+$}

      attr_reader :feed_uri
      attr_reader :entry

      def initialize(feed_uri, entry)
        super(identifier: entry.id.content, timestamp: entry.updated)
        @feed_uri = Stash::Util.to_uri(feed_uri)
        @entry = entry
      end

      def as_wrapper
        @wrapper ||= Stash::Wrapper::StashWrapper.new(
           identifier: Stash::Wrapper::Identifier.new(type: Stash::Wrapper::IdentifierType::DOI, value: doi),
           version: Stash::Wrapper::Version.new(number: 1, date: date),
           license: Stash::Wrapper::License::CC_ZERO,
           descriptive_elements: [datacite_xml]
        )
      end

      private

      def doi
        @doi ||= find_doi
      end

      def date
        updated = entry.updated
        updated.content if updated
      end

      def mrt_datacite_xml
        @mrt_datacite_xml ||= content_for('producer/mrt-datacite.xml')
      end

      def datacite_resource
        @datacite_resource ||= parse_mrt_datacite
      end

      def datacite_xml
        @datacite_xml ||= datacite_resource.save_to_xml
      end

      def parse_mrt_datacite
        bad_contrib_regex = Regexp.new('<contributor contributorType="([^"]+)">\p{Space}*<contributor>([^<]+)</contributor>\p{Space}*</contributor>', Regexp::MULTILINE)
        good_contrib_replacement = "<contributor contributorType=\"\\1\">\n<contributorName>\\2</contributorName>\n</contributor>"
        datacite_xml = mrt_datacite_xml.gsub(bad_contrib_regex, good_contrib_replacement)

        resource = Datacite::Mapping::Resource.parse_xml(datacite_xml, mapping: :nonvalidating)
        resource.identifier = Datacite::Mapping::Identifier.new(value: doi)
        resource
      end

      def find_doi
        mrt_mom = content_for('system/mrt-mom.txt')
        match_result = mrt_mom.match(DOI_PATTERN)
        match_result[0]
      end

      def link_for(title)
        entry.links.find { |l| l.title == title }
      end

      def uri_for(title)
        link = link_for(title)
        href = URI(link.href)
        href.relative? ? feed_uri + href : href
      end

      def content_for(title)
        uri = uri_for(title)
        return nil unless uri
        RestClient.get(uri.to_s).body
      end

    end
  end
end
