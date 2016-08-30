require 'stash_ezid/client'
require 'stash_engine'
require 'stash/wrapper/stash_wrapper'
require 'datacite/mapping'

module Dash2
  module Migrator
    module Importer
      class DOIUpdateTask
        attr_reader :stash_wrapper
        attr_reader :dcs_resource
        attr_reader :se_resource
        attr_reader :doi_value

        def initialize(stash_wrapper:, dcs_resource:, se_resource:)
          @stash_wrapper = stash_wrapper
          @dcs_resource = dcs_resource
          @se_resource = se_resource
        end

        def update!(ezid_client:, tenant:)
          @doi_value ||= DOIUpdateTask.doi_value_from(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource)
          ezid_client.update_metadata(
            "doi:#{doi_value}",
            dcs_resource.write_xml,
            tenant.landing_url("/stash/dataset/doi:#{doi_value}")
          )
          document_migration!
        end

        def document_migration!
          stash_wrapper.version.note = "Migrated at #{Time.now.iso8601}"
        end

        def self.doi_value_from(stash_wrapper:, dcs_resource:, se_resource:)
          sw_doi_value = stash_wrapper.identifier.value
          dcs_doi_value = dcs_resource.identifier.value
          se_doi_value = se_resource.identifier.identifier
          unique_doi_values = [sw_doi_value, dcs_doi_value, se_doi_value].uniq
          return unique_doi_values[0] if unique_doi_values.one?
          raise ArgumentError, "Inconsistent DOI values: stash_wrapper: #{sw_doi_value}, dcs_resource: #{dcs_doi_value}, se_resource: #{se_doi_value}"
        end
      end
    end
  end
end
