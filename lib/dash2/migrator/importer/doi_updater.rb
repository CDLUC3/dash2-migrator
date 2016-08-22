require 'stash_ezid/client'
require 'stash_engine'
require 'stash/wrapper/stash_wrapper'
require 'datacite/mapping'

module Dash2
  module Migrator
    module Importer

      class DOIUpdater
        EZID_METHODS = [:mint_id, :update_metadata].freeze

        attr_reader :ezid_client

        def initialize(ezid_client:)
          @ezid_client = DOIUpdater.ezid_client(ezid_client)
        end

        def update(stash_wrapper:, dcs_resource:, se_resource:)
          doi_value = doi_value(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource)
        end


        def self.ezid_client(client)
          return client if client.is_a?(StashEzid::Client)
          return client if client.to_s =~ /InstanceDouble\(StashEzid::Client\)/ # For RSpec tests
          raise ArgumentError, "ezid_client does not appear to be a StashEzid::Client: #{client || 'nil'}"
        end

        # validators

        private

        def doi_value(stash_wrapper:, dcs_resource:, se_resource:)
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
