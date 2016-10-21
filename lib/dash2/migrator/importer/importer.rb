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

        def import(stash_wrapper:, user_uid:)
          case stash_wrapper.identifier.type
          when Stash::Wrapper::IdentifierType::ARK
            mint_doi_for(stash_wrapper: stash_wrapper)
          when Stash::Wrapper::IdentifierType::DOI
            import_to_stash(stash_wrapper: stash_wrapper, user_uid: user_uid)
          else
            raise ArgumentError, "Bad identifier type in stash wrapper: #{stash_wrapper.identifier.type || 'nil'}"
          end
        end

        def log
          Stash::Harvester.log
        end

        def mint_doi_for(stash_wrapper:)
          raise ArgumentError, "Wrong identifier type; expected ARK, was #{}" unless stash_wrapper.identifier.type == Stash::Wrapper::IdentifierType::ARK
          ark = stash_wrapper.identifier.value
          new_doi = ezid_client.mint_id
          warn "Minted new DOI: #{new_doi} for ARK: #{ark}"
        end

        def import_to_stash(stash_wrapper:, user_uid:)
          raise NoMethodError, "Not implemented yet"
        end
      end
    end
  end
end
