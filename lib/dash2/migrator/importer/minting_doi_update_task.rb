require 'dash2/migrator/importer/doi_update_task'

module Dash2
  module Migrator
    module Importer
      class MintingDOIUpdateTask < DOIUpdateTask
        attr_reader :new_doi

        def initialize(stash_wrapper:, dcs_resource:, se_resource:)
          super
          ensure_unidentified(se_resource)
          ensure_not_migrated
        end

        def old_doi
          @old_doi ||= begin
            old_doi_value = MintingDOIUpdateTask.doi_value_from(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource)
            old_doi = "doi:#{old_doi_value}"
            old_doi
          end
        end

        def update!(ezid_client:, tenant:)
          @new_doi = ezid_client.mint_id
          new_doi_value = new_doi.match(Datacite::Mapping::DOI_PATTERN)[0]

          stash_wrapper.identifier.value = new_doi_value
          dcs_resource.identifier.value = new_doi_value
          update_se_identifier(new_doi_value)

          @doi_value = new_doi_value
          super
        end

        def update_se_identifier(new_doi_value)
          se_ident = se_resource.identifier
          return se_ident.update(identifier: new_doi_value) if se_ident

          se_ident = StashEngine::Identifier.create(identifier: new_doi_value, identifier_type: 'DOI')
          se_resource.identifier_id = se_ident.id
          se_resource.save
        end

        def document_migration!
          raise 'new DOI not minted' unless new_doi
          set_version_note!
          alt_ident = Datacite::Mapping::AlternateIdentifier.new(type: 'migrated from', value: old_doi)
          add_alt_ident_xml(alt_ident)
          add_alt_ident_db(alt_ident)
        end

        def self.doi_value_from(stash_wrapper:, dcs_resource:)
          sw_doi_value = (sw_ident = stash_wrapper.identifier) && normalize(sw_ident.value)
          dcs_doi_value = (dcs_ident = dcs_resource.identifier) && normalize(dcs_ident.value)
          return sw_doi_value if sw_doi_value == dcs_doi_value
          raise ArgumentError, "Inconsistent DOI values: stash_wrapper: #{sw_doi_value}, dcs_resource: #{dcs_doi_value}"
        end

        def self.normalize(doi_value)
          doi_value && doi_value.upcase.strip
        end

        def ensure_not_migrated
          alt_ident = StashDatacite::AlternateIdentifier.find_by(alternate_identifier: old_doi)
          raise ArgumentError, "#{old_doi} already migrated with ID: #{alt_ident.resource_id}" if alt_ident
        end

        def ensure_unidentified(se_resource)
          se_ident = se_resource.identifier
          raise ArgumentError, "Resource with ID #{se_resource.id} should not have an identifier: #{se_ident.identifier || 'nil'} (id: #{se_ident.id || 'nil'}" if se_ident
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
