require 'dash2/migrator/importer/doi_updater'

module Dash2
  module Migrator
    module Importer
      class MintingDOIUpdater < DOIUpdater
        def create_update_task(stash_wrapper:, dcs_resource:, se_resource:)
          MintingDOIUpdateTask.new(
            stash_wrapper: stash_wrapper,
            dcs_resource: dcs_resource,
            se_resource: se_resource
          )
        end
      end

      class MintingDOIUpdateTask < DOIUpdateTask

        attr_reader :new_doi

        def initialize(stash_wrapper:, dcs_resource:, se_resource:)
          super
          if StashDatacite::AlternateIdentifier.where(alternate_identifier: old_doi)
            raise ArgumentError, "#{old_doi} already migrated"
          end
        end

        def old_doi
          @old_doi ||= begin
            old_doi_value = DOIUpdateTask.doi_value_from(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource)
            old_doi = "doi:#{old_doi_value}"
            old_doi
          end
        end

        def update!(ezid_client:, tenant:)
          @new_doi = ezid_client.mint_id
          new_doi_value = new_doi.match(Datacite::Mapping::DOI_PATTERN)[0]

          stash_wrapper.identifier.value = new_doi_value
          dcs_resource.identifier.value = new_doi_value
          se_resource.identifier.identifier = new_doi_value
          se_resource.identifier.save

          super
        end

        def document_migration!
          raise 'new DOI not minted' unless new_doi
          set_version_note!
          alt_ident = Datacite::Mapping::AlternateIdentifier.new(type: 'migrated from', value: old_doi)
          add_alt_ident_xml(alt_ident)
          add_alt_ident_db(alt_ident)
        end

        private

        def set_version_note!
          stash_wrapper.version.note = "Migrated from #{old_doi} to #{new_doi} at #{Time.now.iso8601} in #{ENV['STASH_ENV']}."
        end

        def add_alt_ident_xml(alt_ident)
          dcs_resource.alternate_identifiers << alt_ident
        end

        def add_alt_ident_db(alt_ident)
          StashDatacite::AlternateIdentifier.create(
            resource_id: se_resource.id,
            alternate_identifier_type: alt_ident.type,
            alternate_identifier: alt_ident.value
          ).save
        end

      end

    end
  end
end
