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
        LOCAL_ID_PATTERN = /localIdentifier:\s*([a-z]+);/

        attr_reader :tenant_id
        attr_reader :feed_uri
        attr_reader :entry
        attr_reader :user_provider

        def initialize(user_provider, tenant_id, feed_uri, entry)
          super(identifier: entry.id.content, timestamp: MerrittAtomHarvestedRecord.extract_timestamp(entry))
          @tenant_id = tenant_id
          @feed_uri = Stash::Util.to_uri(feed_uri)
          @entry = entry
          @user_provider = user_provider
        end

        def log
          ::Stash::Harvester.log
        end

        def as_wrapper
          @wrapper ||= begin
            builder = StashWrapperBuilder.new(
              entry: entry,
              datacite_resource: build_datacite_resource
            )
            builder.build
          end
        end

        def stash_version
          @stash_version ||= begin
            (wrapper_xml = content_for('producer/stash-wrapper.xml')) &&
              (wrapper = Stash::Wrapper::StashWrapper.parse_xml(wrapper_xml)) &&
              wrapper.version.version_number
          rescue XML::MappingError => e
            log.error(e)
            nil
          end
        end

        def merritt_version
          @merritt_version ||= begin
            (wrapper_uri = uri_for('producer/stash-wrapper.xml')) &&
              (version_str = %r{.*/([0-9]+)/producer%2Fstash-wrapper.xml}.match(wrapper_uri.to_s)[1]) &&
              version_str.to_i
          end
        end

        def user_uid
          user_provider.ensure_uid!(self)
        end

        def doi
          @doi ||= begin
            doi_match_data = mrt_mom.match(DOI_PATTERN)
            log.warn('no DOI found in mrt-mom.txt') unless doi_match_data
            doi_match_data[0].strip if doi_match_data
          end
        end

        def ark
          @ark ||= begin
            ark_match_data = mrt_mom.match(ARK_PATTERN)
            raise 'no ARK found in mrt-mom.txt' unless ark_match_data
            ark = ark_match_data[0].strip

            # basename = "#{tenant_id}-#{ark.sub(':', '+').gsub('/', '=')}-mrt-mom.txt"
            # filename = "spec/data/harvester/moms/#{basename}"
            # if File.exists?(filename)
            #   warn("#{filename} already exists")
            # else
            #   warn("Writing new mrt-mom file #{basename}")
            #   File.open("tmp/#{basename}", 'wb') { |f| f.write(mrt_mom) }
            # end

            ark
          rescue => e
            log.error(e)
            nil
          end
        end

        def local_id
          @local_id ||= begin
            local_id_match_data = mrt_mom.match(LOCAL_ID_PATTERN)
            log.warn('no local ID found in mrt-mom.txt') unless local_id_match_data
            local_id_match_data[1] if local_id_match_data
          end
        end

        def date_published
          @date_published ||= begin
            published = entry.published
            log.warn('no published date for entry') unless published
            published.content
          end
        end

        def mrt_eml
          @mrt_eml ||= content_for('producer/mrt-eml.xml')
        end

        def mrt_datacite_xml
          @mrt_datacite_xml ||= begin
            content = content_for('producer/mrt-datacite.xml')
            # if content
            #   basename = "#{tenant_id}-#{ark.sub(':', '+').gsub('/', '=')}-mrt-datacite.xml"
            #   filename = "spec/data/datacite/dash1-datacite-xml/#{basename}"
            #   if File.exists?(filename)
            #     warn("#{filename} already exists")
            #   else
            #     warn("Writing new datacite file #{basename}")
            #     File.open("tmp/#{basename}", 'wb') { |f| f.write(content) }
            #   end
            # end
            content
          end
        end

        def identifier_value
          @identifier_value ||= doi ? doi : ark
        end

        def title
          datacite_resource = as_wrapper.datacite_resource
          datacite_resource.default_title
        end

        def build_datacite_resource
          return parse_mrt_datacite if mrt_datacite_xml
          return parse_mrt_eml if mrt_eml
          raise "No Datacite or EML XML found in entry #{identifier_value}"
        end

        def parse_mrt_eml
          EmlDataciteMapper.to_datacite(mrt_eml, identifier_value)
        end

        def parse_mrt_datacite
          resource = Datacite::Mapping::Resource.parse_mrt_datacite(mrt_datacite_xml, identifier_value)
          date_available = resource.dates.find { |d| d.type == Datacite::Mapping::DateType::AVAILABLE }
          resource.dates << Datacite::Mapping::Date.new(type: Datacite::Mapping::DateType::AVAILABLE, value: date_published) unless date_available
          resource
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
            response = RestClient.get(uri.to_s)
            content = response.body
            if content.include?('HTTP/1.1 500')
              raise RestClient::InternalServerError
            end
            content
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
