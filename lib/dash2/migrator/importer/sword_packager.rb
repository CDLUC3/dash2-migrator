require 'stash/sword'
require 'datacite/mapping'
require 'stash/wrapper'
require 'stash_engine'
require 'dash2/migrator/importer/zip_package_builder'

module Dash2
  module Migrator
    module Importer

      class SwordPackager

        attr_reader :sword_client
        attr_reader :create_placeholder_files

        def initialize(sword_client:, create_placeholder_files: false)
          raise ArgumentError, 'Migrator should not be creating placeholder files in production environment' if create_placeholder_files && Migrator.production?
          @sword_client = SwordPackager.sword_client(sword_client)
          @create_placeholder_files = create_placeholder_files
        end

        def self.sword_client(client)
          return client if client.respond_to?(:create) && client.respond_to?(:update)
          return client if client.to_s =~ /InstanceDouble\(Stash::Sword::Client\)/ # For RSpec tests
          raise ArgumentError, "sword_client does not appear to be a Stash::Sword::Client: #{client || 'nil'}"
        end

        def log
          Dash2::Migrator.log
        end

        # TODO: replace SwordCreator/SwordUpdater with SubmissionTask or similar
        # @return [String] the path to the submitted zipfile
        def submit(stash_wrapper:, dcs_resource:, se_resource:, tenant:)
          package_builder = make_package_builder(dcs_resource, se_resource, stash_wrapper, tenant)
          zipfile = package_builder.make_package
          SubmissionTask.new(se_resource: se_resource, zipfile: zipfile, sword_client: sword_client).submit!
        end

        private

        def make_package_builder(dcs_resource, se_resource, stash_wrapper, tenant)
          ZipPackageBuilder.new(
            stash_wrapper: stash_wrapper,
            dcs_resource: dcs_resource,
            se_resource: se_resource,
            tenant: tenant,
            create_placeholder_files: create_placeholder_files
          )
        end
      end

      class SubmissionTask
        RETRIES = 3

        attr_reader :se_resource
        attr_reader :zipfile
        attr_reader :sword_client

        def initialize(se_resource:, zipfile:, sword_client:)
          @se_resource = se_resource
          @zipfile = zipfile
          @sword_client = sword_client
        end

        def submit!
          edit_iri = se_resource.update_uri
          edit_iri ? update(edit_iri) : create
          save_resource!
          zipfile
        end

        private

        def save_resource!
          se_resource.set_state('published')
          se_resource.update_version(zipfile)
          se_resource.save
        end

        def id_val
          se_resource.identifier.identifier
        end

        def doi
          "doi:#{id_val}"
        end

        def create
          receipt = submit_create
          se_resource.download_uri = receipt.em_iri
          se_resource.update_uri = receipt.edit_iri
          Stash::Harvester.log.info("create(doi: #{id_val}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) completed with em_iri #{receipt.em_iri}, edit_iri #{receipt.edit_iri}")
        end

        def submit_create(retries = RETRIES)
          return sword_client.create(doi: doi, zipfile: zipfile)
        rescue RestClient::Exceptions::ReadTimeout
          return submit(retries - 1) if retries > 0
          raise "Unable to submit #{zipfile} for #{doi}: too many timeouts"
        end

        def update(edit_iri)
          status = submit_update(edit_iri)
          Stash::Harvester.log.info("update(edit_iri: #{edit_iri}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) completed with status #{status}")
        end

        def submit_update(edit_iri, retries = RETRIES)
          return sword_client.update(edit_iri: edit_iri, zipfile: zipfile)
        rescue RestClient::Exceptions::ReadTimeout
          return submit(edit_iri, retries - 1) if retries > 0
          raise "Unable to submit #{zipfile} to #{edit_iri}: too many timeouts"
        end
      end
    end
  end
end
