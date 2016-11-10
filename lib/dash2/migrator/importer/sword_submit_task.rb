require 'stash/sword'
require 'stash/wrapper'
require 'stash_engine'

module Dash2
  module Migrator
    module Importer
      class SwordSubmitTask
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
          se_resource.current_state = 'published'
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
          Migrator.log.info("posting create(doi: #{id_val}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) to #{sword_client.collection_uri}")
          receipt = submit_create
          se_resource.download_uri = receipt.em_iri
          se_resource.update_uri = receipt.edit_iri
          Migrator.log.info("create(doi: #{id_val}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) completed with em_iri #{receipt.em_iri}, edit_iri #{receipt.edit_iri}")
        end

        def submit_create(retries = RETRIES)
          return sword_client.create(doi: doi, zipfile: zipfile)
        rescue RestClient::Exceptions::ReadTimeout
          Migrator.log.warn("Read timeout posting SWORD update for DOI #{doi}; #{retries} retries remaining")
          return submit_create(retries - 1) if retries > 0
          raise RestClient::Exceptions::ReadTimeout, "Unable to submit #{zipfile} for #{doi}: too many timeouts"
        end

        def update(edit_iri)
          Migrator.log.info("posting update(edit_iri: #{edit_iri}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val})")
          status = submit_update(edit_iri)
          Migrator.log.info("update(edit_iri: #{edit_iri}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) completed with status #{status}")
        end

        def submit_update(edit_iri, retries = RETRIES)
          return sword_client.update(edit_iri: edit_iri, zipfile: zipfile)
        rescue RestClient::Exceptions::ReadTimeout
          Migrator.log.warn("Read timeout posting SWORD update to #{edit_iri}; #{retries} retries remaining")
          return submit_update(edit_iri, retries - 1) if retries > 0
          raise RestClient::Exceptions::ReadTimeout, "Unable to submit #{zipfile} to #{edit_iri}: too many timeouts"
        end
      end
    end
  end
end
