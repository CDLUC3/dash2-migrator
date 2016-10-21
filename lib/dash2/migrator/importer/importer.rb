require 'logger'

module Dash2
  module Migrator
    module Importer
      class Importer

        attr_reader :tenant
        attr_reader :ezid_client
        attr_reader :sword_client

        def initialize(tenant:, ezid_client:, sword_client:)
          @tenant = tenant
          @ezid_client = ezid_client
          @sword_client = sword_client
        end

        def import(merritt_landing_uri:, stash_wrapper:, user_uid:)
          case stash_wrapper.identifier.type
          when Stash::Wrapper::IdentifierType::ARK
            mint_doi_for(stash_wrapper: stash_wrapper, merritt_landing_uri: merritt_landing_uri)
          when Stash::Wrapper::IdentifierType::DOI
            import_to_stash(stash_wrapper: stash_wrapper, user_uid: user_uid)
          else
            raise ArgumentError, "Bad identifier type in stash wrapper: #{stash_wrapper.identifier.type || 'nil'}"
          end
        end

        def log
          Stash::Harvester.log
        end

        def mint_doi_for(stash_wrapper:, merritt_landing_uri:)
          ark = stash_wrapper.identifier.value
          datacite_resource = stash_wrapper.datacite_resource
          new_doi = ezid_client.mint_id
          datacite_resource.identifier = Datacite::Mapping::Identifier.from_doi(new_doi)
          datacite_resource.related_identifiers << Datacite::Mapping::RelatedIdentifier.new(
            identifier_type: Datacite::Mapping::RelatedIdentifierType::ARK,
            value: ark,
            relation_type: Datacite::Mapping::RelationType::IS_IDENTICAL_TO
          )
          datacite3_xml = datacite_resource.write_xml(mapping: :datacite_3)
          ezid_client.update_metadata(new_doi, datacite3_xml, merritt_landing_uri)
          warn "Minted new DOI #{new_doi} for ARK #{ark} with landing page #{merritt_landing_uri}"
        end

        def import_to_stash(stash_wrapper:, user_uid:)
          raise NoMethodError, "Not implemented yet"
        end
      end
    end
  end
end
