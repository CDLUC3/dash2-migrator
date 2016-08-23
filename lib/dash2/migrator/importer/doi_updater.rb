require 'dash2/migrator/importer/doi_update_task'
require 'dash2/migrator/importer/minting_doi_update_task'

module Dash2
  module Migrator
    module Importer
      class DOIUpdater
        EZID_METHODS = [:mint_id, :update_metadata].freeze

        attr_reader :ezid_client
        attr_reader :tenant

        def initialize(ezid_client:, tenant:, mint_dois: false)
          raise ArgumentError, 'Migrator should not be minting DOIs in production environment' if mint_dois && Migrator.production?
          @ezid_client = DOIUpdater.ezid_client(ezid_client)
          @tenant = DOIUpdater.tenant(tenant)
          @mint_dois = mint_dois
        end

        def mint_doi?
          @mint_dois
        end

        def update(stash_wrapper:, dcs_resource:, se_resource:)
          update_task = create_update_task(
            stash_wrapper: stash_wrapper,
            dcs_resource: dcs_resource,
            se_resource: se_resource
          )
          update_task.update!(ezid_client: ezid_client, tenant: tenant)
        end

        def self.tenant(tenant)
          return tenant if tenant.respond_to?(:landing_url)
          return tenant if tenant.to_s =~ /InstanceDouble\(StashEngine::Tenant\)/ # For RSpec tests
          raise ArgumentError, "tenant does not appear to be a StashEngine::Tenant: #{tenant || 'nil'}"
        end

        def self.ezid_client(client)
          return client if client.respond_to?(:update_metadata)
          return client if client.to_s =~ /InstanceDouble\(StashEzid::Client\)/ # For RSpec tests
          raise ArgumentError, "ezid_client does not appear to be a StashEzid::Client: #{client || 'nil'}"
        end

        def create_update_task(stash_wrapper:, dcs_resource:, se_resource:)
          task_class = mint_doi? ? MintingDOIUpdateTask : DOIUpdateTask
          task_class.new(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource)
        end
      end

    end
  end
end
