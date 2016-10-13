require 'rss'
require 'rest-client'
require 'stash/harvester'
require 'datacite/mapping'
require 'datacite/mapping/datacite_extensions'

module Dash2
  module Migrator
    module Harvester
      class MerrittAtomHarvestedRecord < Stash::Harvester::HarvestedRecord
        DOI_PATTERN = %r{10\.[^/\s]+/[^;\s]+$}
        ARK_PATTERN = %r{ark:/[a-z0-9]+/[a-z0-9]+}
        MAX_FILES = 20

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
          identifier = doi ?
            Stash::Wrapper::Identifier.new(type: Stash::Wrapper::IdentifierType::DOI, value: doi) :
            Stash::Wrapper::Identifier.new(type: Stash::Wrapper::IdentifierType::ARK, value: ark)
          @wrapper ||= Stash::Wrapper::StashWrapper.new(
            identifier: identifier,
            version: Stash::Wrapper::Version.new(number: 1, date: date),
            embargo: Stash::Wrapper::Embargo.new(type: Stash::Wrapper::EmbargoType::NONE, period: Stash::Wrapper::EmbargoType::NONE.value, start_date: date_published, end_date: date_published),
            license: stash_license,
            inventory: Stash::Wrapper::Inventory.new(files: stash_files),
            descriptive_elements: [datacite_xml]
          )
        end

        def user_uid
          raise NoMethodError, 'user_uid not implemented yet'
        end

        def doi
          @doi ||= find_doi
        end

        def ark
          @ark ||= find_ark
        end

        def date
          MerrittAtomHarvestedRecord.extract_timestamp(entry)
        end

        def date_published
          (published = entry.published) && published.content
        end

        def mrt_eml
          @mrt_eml ||= content_for('producer/mrt-eml.xml')
        end

        def mrt_datacite_xml
          @mrt_datacite_xml ||= content_for('producer/mrt-datacite.xml')
        end

        def datacite_resource
          identifier_value = doi ? doi : ark
          @datacite_resource ||= begin
            resource = Datacite::Mapping::Resource.parse_mrt_datacite(mrt_datacite_xml, identifier_value)
            resource.dates = [Datacite::Mapping::Date.new(type: Datacite::Mapping::DateType::AVAILABLE, value: date_published)] unless resource.dates && !resource.dates.empty?
            resource
          end
        end

        def datacite_xml
          @datacite_xml ||= datacite_resource.save_to_xml
        end

        def mrt_mom
          @mrt_mom ||= begin
            mrt_mom = content_for('system/mrt-mom.txt')
            raise "mrt-mom.txt not found at #{uri_for('system/mrt-mom.txt')}" unless mrt_mom
            mrt_mom
          end
        end

        def find_ark
          ark_match_data = mrt_mom.match(ARK_PATTERN)
          warn 'no ARK found in mrt-mom.txt' unless ark_match_data
          ark_match_data[0].strip if ark_match_data
        end

        def find_doi
          doi_match_data = mrt_mom.match(DOI_PATTERN)
          warn 'no DOI found in mrt-mom.txt' unless doi_match_data
          doi_match_data[0].strip if doi_match_data
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
          @file_links ||= entry.links.select { |l| (title = l.title) && title.start_with?('producer/') && !title.start_with?('producer/mrt-') }
        end

        def all_stash_files
          @all_stash_files ||= file_links.map { |l| Stash::Wrapper::StashFile.new(pathname: l.title.match(%r{(?<=/)(.*)})[0], size_bytes: l.length.to_i, mime_type: l.type) }
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
