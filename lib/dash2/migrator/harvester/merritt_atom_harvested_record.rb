require 'rss'
require 'rest-client'
require 'stash/harvester'
require 'datacite/mapping'
require 'datacite/mapping/datacite_extensions'

module Dash2
  module Migrator
    module Harvester
      class MerrittAtomHarvestedRecord < Stash::Harvester::HarvestedRecord
        DOI_PATTERN = %r{10\..+/.+$}
        MAX_FILES = 20

        attr_reader :feed_uri
        attr_reader :entry

        def initialize(feed_uri, entry)
          super(identifier: entry.id.content, timestamp: entry.updated)
          @feed_uri = Stash::Util.to_uri(feed_uri)
          @entry = entry
        end

        def log
          ::Stash::Harvester.log
        end

        def as_wrapper
          @wrapper ||= Stash::Wrapper::StashWrapper.new(
            identifier: Stash::Wrapper::Identifier.new(type: Stash::Wrapper::IdentifierType::DOI, value: doi),
            version: Stash::Wrapper::Version.new(number: 1, date: date),
            embargo: Stash::Wrapper::Embargo.new(type: Stash::Wrapper::EmbargoType::NONE, period: Stash::Wrapper::EmbargoType::NONE.value, start_date: date_published, end_date: date_published),
            license: stash_license,
            inventory: Stash::Wrapper::Inventory.new(files: stash_files),
            descriptive_elements: [datacite_xml]
          )
        end

        def user_uid
          raise 'user_uid not implemented'
        end

        private

        def doi
          @doi ||= find_doi
        end

        def date
          (updated = entry.updated) && updated.content
        end

        def date_published
          (published = entry.published) && published.content
        end

        def mrt_datacite_xml
          @mrt_datacite_xml ||= content_for('producer/mrt-datacite.xml')
        end

        def datacite_resource
          @datacite_resource ||= begin
            resource = Datacite::Mapping::Resource.parse_mrt_datacite(mrt_datacite_xml, doi)
            resource.dates = [Datacite::Mapping::Date.new(type: Datacite::Mapping::DateType::AVAILABLE, value: date_published)] unless resource.dates && !resource.dates.empty?
            resource
          end
        end

        def datacite_xml
          @datacite_xml ||= datacite_resource.save_to_xml
        end

        def find_doi
          mrt_mom = content_for('system/mrt-mom.txt')
          mrt_mom.match(DOI_PATTERN)[0]
        end

        def stash_license
          rights_list = datacite_resource.rights_list
          rights = rights_list[0]
          rights_url = rights.uri.to_s
          return Stash::Wrapper::License::CC_ZERO if rights_url.include?('cc0') || rights_url.include?('publicdomain')
          return Stash::Wrapper::License::CC_BY if rights_url.include?('licenses/by')
          Stash::Wrapper::License.new(name: rights.value, uri: rights.uri)
        end

        def stash_files
          @stash_files ||= begin
            return all_stash_files unless all_stash_files.size > MAX_FILES && !Migrator.production?
            log.warn "#{doi}: Taking only first #{MAX_FILES} of #{file_links.size} files"
            all_stash_files.first(MAX_FILES)
          end
        end

        def file_links
          entry.links.select { |l| (title = l.title) && title.start_with?('producer/') && !title.start_with?('producer/mrt-') }
        end

        def all_stash_files
          file_links.map { |l| Stash::Wrapper::StashFile.new(pathname: l.title.match(%r{(?<=/)(.*)})[0], size_bytes: l.length.to_i, mime_type: l.type) }
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
          begin
            RestClient.get(uri.to_s).body
          rescue => e
            log.error("Error fetching URI #{uri}: #{e}")
            raise
          end
        end

      end
    end
  end
end
