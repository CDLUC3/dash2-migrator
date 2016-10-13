require 'rss'
require 'rest-client'
require 'stash/harvester'
require 'datacite/mapping'
require 'datacite/mapping/datacite_extensions'
require 'dash2/migrator/harvester/stash_wrapper_builder'

module Dash2
  module Migrator
    module Harvester
      class MerrittAtomHarvestedRecord < Stash::Harvester::HarvestedRecord
        DOI_PATTERN = %r{10\.[^/\s]+/[^;\s]+$}
        ARK_PATTERN = %r{ark:/[a-z0-9]+/[a-z0-9]+}

        attr_reader :tenant_id
        attr_reader :feed_uri
        attr_reader :entry

        def initialize(tenant_id, feed_uri, entry)
          super(identifier: entry.id.content, timestamp: MerrittAtomHarvestedRecord.extract_timestamp(entry))
          @tenant_id = tenant_id
          @feed_uri = Stash::Util.to_uri(feed_uri)
          @entry = entry
        end

        def log
          ::Stash::Harvester.log
        end

        def as_wrapper
          @wrapper ||= begin
            builder = StashWrapperBuilder.new(
              entry: entry,
              datacite_resource: datacite_resource
            )
            builder.build
          end
        end

        def user_uid
          raise NoMethodError, 'user_uid not implemented yet'
        end

        def doi
          @doi ||= begin
            doi_match_data = mrt_mom.match(DOI_PATTERN)
            warn 'no DOI found in mrt-mom.txt' unless doi_match_data
            doi_match_data[0].strip if doi_match_data
          end
        end

        def ark
          @ark ||= begin
            ark_match_data = mrt_mom.match(ARK_PATTERN)
            warn 'no ARK found in mrt-mom.txt' unless ark_match_data
            ark_match_data[0].strip if ark_match_data
          end
        end

        def date_published
          @date_published ||= begin
            published = entry.published
            warn 'no published date for entry' unless published
            published.content
          end
        end

        def mrt_eml
          @mrt_eml ||= content_for('producer/mrt-eml.xml')
        end

        def mrt_datacite_xml
          @mrt_datacite_xml ||= content_for('producer/mrt-datacite.xml')
        end

        def datacite_resource
          @datacite_resource ||= begin
            identifier_value = doi ? doi : ark
            resource = Datacite::Mapping::Resource.parse_mrt_datacite(mrt_datacite_xml, identifier_value)
            date_available = resource.dates.find { |d| d.type == Datacite::Mapping::DateType::AVAILABLE }
            resource.dates << Datacite::Mapping::Date.new(type: Datacite::Mapping::DateType::AVAILABLE, value: date_published) unless date_available
            resource
          end
        end

        def mrt_mom
          @mrt_mom ||= begin
            mrt_mom = content_for('system/mrt-mom.txt')
            raise "mrt-mom.txt not found at #{uri_for('system/mrt-mom.txt')}" unless mrt_mom
            mrt_mom
          end
        end

        def link_for(title)
          entry.links.find { |l| l.title == title }
        end

        def uri_for(title)
          return nil unless (link = link_for(title))
          href = URI(link.href)
          href.relative? ? feed_uri + href : href
        end

        def content_for(title)
          return nil unless (uri = uri_for(title))
          begin
            RestClient.get(uri.to_s).body
          rescue => e
            log.error("Error fetching URI #{uri}: #{e}")
            raise
          end
        end

        def self.extract_timestamp(entry)
          (updated = entry.updated) && updated.content
        end

      end
    end
  end
end
