require 'stash/sword'
require 'datacite/mapping'
require 'stash/wrapper'
require 'stash_engine'
require 'dash2/migrator/importer/zip_package_builder'

module Dash2
  module Migrator
    module Importer

      class SwordPackager

        RETRIES = 3

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
          Stash::Harvester.log
        end

        # TODO: replace SwordCreator/SwordUpdater with SubmissionTask or similar
        def submit(stash_wrapper:, dcs_resource:, se_resource:, tenant:)
          package_builder = make_package_builder(dcs_resource, se_resource, stash_wrapper, tenant)
          sword_submit(se_resource, package_builder.make_package)
        end

        def make_package_builder(dcs_resource, se_resource, stash_wrapper, tenant)
          ZipPackageBuilder.new(
            stash_wrapper: stash_wrapper,
            dcs_resource: dcs_resource,
            se_resource: se_resource,
            tenant: tenant,
            create_placeholder_files: create_placeholder_files
          )
        end

        private

        def sword_submit(se_resource, zipfile)
          edit_iri = se_resource.update_uri
          if edit_iri
            submit_update(se_resource, edit_iri, zipfile)
          else
            submit_create(se_resource, zipfile)
          end
          se_resource.set_state('published')
          se_resource.update_version(zipfile)
          se_resource.save
        end

        def submit_create(se_resource, zipfile)
          receipt = SwordCreator.new(
            se_resource: se_resource,
            zipfile: zipfile,
            sword_client: sword_client
          ).submit
          se_resource.download_uri = receipt.em_iri
          se_resource.update_uri = receipt.edit_iri
          id_val = se_resource.identifier.identifier
          Stash::Harvester.log.info("create(doi: #{doi}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) completed with em_iri #{receipt.em_iri}, edit_iri #{receipt.edit_iri}")
        end

        def submit_update(se_resource, edit_iri, zipfile)
          status = SwordUpdater.new(
            se_resource: se_resource,
            edit_iri: edit_iri,
            zipfile: zipfile,
            sword_client: sword_client
          ).submit
          id_val = se_resource.identifier.identifier
          Stash::Harvester.log.info("update(edit_iri: #{edit_iri}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) completed with status #{status}")
        end
      end

      class SwordUpdater

        attr_reader :se_resource
        attr_reader :edit_iri
        attr_reader :zipfile
        attr_reader :sword_client

        def initialize(se_resource:, edit_iri:, zipfile:, sword_client:)
          @se_resource = se_resource
          @edit_iri = edit_iri
          @zipfile = zipfile
          @sword_client = sword_client
        end

        def submit(retries = SwordPackager.RETRIES)
          return sword_client.update(edit_iri: edit_iri, zipfile: zipfile)
        rescue RestClient::Exceptions::ReadTimeout
          return submit(retries - 1) if retries > 0
          raise "Unable to submit #{zipfile} to #{edit_iri}: too many timeouts"
        end
      end

      class SwordCreator
        attr_reader :se_resource
        attr_reader :doi
        attr_reader :zipfile
        attr_reader :sword_client

        def initialize(se_resource:, zipfile:, sword_client:)
          @se_resource = se_resource
          @zipfile = zipfile
          @doi = "doi:#{se_resource.identifier.identifier}"
          @sword_client = sword_client
        end

        def submit(retries = SwordPackager.RETRIES)
          return sword_client.create(doi: doi, zipfile: zipfile)
        rescue RestClient::Exceptions::ReadTimeout
          return submit(retries - 1) if retries > 0
          raise "Unable to submit #{zipfile} for #{doi}: too many timeouts"
        end
      end

    end
  end
end
