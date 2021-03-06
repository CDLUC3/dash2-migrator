require 'stash/wrapper'
require 'datacite/mapping'
require 'datacite/mapping/datacite_extensions'

module Dash2
  module Migrator
    module Harvester
      class StashWrapperBuilder
        include Stash::Wrapper

        MAX_FILES = 20

        attr_reader :entry
        attr_reader :datacite_resource

        def initialize(entry:, datacite_resource:)
          @entry = entry
          @datacite_resource = datacite_resource
        end

        def log
          ::Stash::Harvester.log
        end

        def build
          StashWrapper.new(
            identifier: sw_ident,
            version: Version.new(number: 1, date: date),
            embargo: Embargo.new(type: EmbargoType::NONE, period: EmbargoType::NONE.value, start_date: date_published, end_date: date_published),
            license: stash_license,
            inventory: Inventory.new(files: stash_files),
            descriptive_elements: [datacite_xml]
          )
        end

        def sw_ident
          @sw_ident ||= begin
            dcs_ident = datacite_resource.identifier
            sw_ident_type = IdentifierType.find_by_value_str(dcs_ident.identifier_type)
            sw_ident_value = dcs_ident.value
            Identifier.new(type: sw_ident_type, value: sw_ident_value)
          end
        end

        def date
          @date ||= begin
            timestamp = MerrittAtomHarvestedRecord.extract_timestamp(entry)
            warn 'no timestamp found for entry' unless entry
            timestamp
          end
        end

        def date_published
          @date_available ||= begin
            date_available = datacite_resource.dates.find { |d| d.type == Datacite::Mapping::DateType::AVAILABLE }
            warn 'no date available found for resource' unless date_available
            date_available && date_available.date_value.date
          end
        end

        def stash_license
          return License::CC_ZERO if rights_url.include?('cc0') || rights_url.include?('publicdomain')
          return License::CC_BY if rights_url.include?('licenses/by')
          License.new(name: rights.value, uri: rights.uri)
        end

        def stash_files
          @stash_files ||= begin
            num_files = all_stash_files.size
            return all_stash_files unless num_files > MAX_FILES && !Migrator.production?
            log.warn "#{sw_ident.value}: Taking only first #{MAX_FILES} of #{num_files} files"
            all_stash_files.first(MAX_FILES)
          end
        end

        def datacite_xml
          @datacite_xml ||= datacite_resource.save_to_xml
        end

        private

        def rights
          @rights ||= begin
            rights_list = datacite_resource.rights_list
            rights_list[0]
          end
        end

        def rights_url
          @rights_uri ||= begin
            rights.uri.to_s
          end
        end

        def all_stash_files
          @all_stash_files ||= begin
            file_links = entry.links.select { |l| data_file?(l) }
            file_links.map do |link|
              StashFile.new(
                pathname: link.title.match(%r{(?<=/)(.*)})[0],
                size_bytes: link.length.to_i,
                mime_type: link.type
              )
            end
          end
        end

        def data_file?(link)
          return false unless (title = link.title)
          return false unless title.start_with?('producer/')
          !title.start_with?('producer/mrt-')
        end
      end
    end
  end
end
