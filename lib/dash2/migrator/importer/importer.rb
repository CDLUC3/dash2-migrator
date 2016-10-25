require 'logger'
require 'stash_engine'
require 'dash2/migrator/importer/sword_packager'

module StashEngine
  class Resource < ActiveRecord::Base

    def identifier_type
      identifier && identifier.identifier_type
    end

    def identifier_value
      identifier && identifier.identifier
    end

    def first_alternate_identifier(type:)
      alternate_identifiers
        .where(alternate_identifier_type: type)
        .first
    end

    def first_identical_resource
      identical_resources.first
    end

    def identical_resources
      se_ident = identifier
      StashEngine::Identifier
        .where(identifier: se_ident.identifier)
        .where.not(id: se_ident.id)
        .flat_map(&:resources)
    end
  end
end

module Dash2
  module Migrator
    module Importer
      class Importer

        MIGRATED_FROM = 'migrated from'.freeze
        SWORD_PATTERN = %r{(https?)://([^/]+)/mrtsword/collection/([^/]+)}

        attr_reader :tenant
        attr_reader :ezid_client
        attr_reader :sword_client

        def initialize(tenant:, ezid_client:, sword_client:)
          @tenant = tenant
          @ezid_client = ezid_client
          @sword_client = sword_client
        end

        def import(stash_wrapper:, user_uid:)
          if stash_wrapper.identifier.type == Stash::Wrapper::IdentifierType::ARK && Migrator.production?
            mint_real_doi_for(stash_wrapper: stash_wrapper)
          else
            import_to_stash(stash_wrapper: stash_wrapper, user_uid: user_uid)
          end
        end

        def log
          Stash::Harvester.log
        end

        def edit_uri_base
          @edit_uri_base ||= begin
            if (match_data = SWORD_PATTERN.match(sword_client.collection_uri))
              protocol = match_data[1]
              server = match_data[2]
              collection = match_data[3]
              "#{protocol}://#{server}/mrtsword/edit/#{collection}/"
            end
          end
        end

        def edit_uri_for(doi)
          "#{edit_uri_base}#{ERB::Util.url_encode(doi)}"
        end

        def sword_packager
          SwordPackager.new(sword_client: sword_client, create_placeholder_files: !Migrator.production?)
        end

        def mint_real_doi_for(stash_wrapper:)
          sw_ident = stash_wrapper.identifier
          raise ArgumentError, "Wrong identifier type; expected ARK, was #{sw_ident.type}" unless sw_ident.type == Stash::Wrapper::IdentifierType::ARK
          log.warn "Minted new DOI: #{ezid_client.mint_id} for ARK: #{sw_ident.value}"
        end

        def import_to_stash(stash_wrapper:, user_uid:)
          se_resource = build_se_resource(stash_wrapper, user_uid)

          if (existing_alt_ident = alt_ident_for(se_resource))
            existing_resource = StashEngine::Resource.find(existing_alt_ident.resource_id)
            final_doi = replace_existing_resource(se_resource, stash_wrapper, existing_resource)
          elsif (existing_resource = se_resource.first_identical_resource)
            final_doi = replace_existing_resource(se_resource, stash_wrapper, existing_resource)
          elsif Migrator.production?
            wrapper_doi = id_for(se_resource.identifier_value)
            se_resource.update_uri = edit_uri_for(wrapper_doi)
            # TODO: download URI?
            final_doi = wrapper_doi
          else
            final_doi = migrate_test_record(stash_wrapper, se_resource)
          end

          dcs_resource = update_ezid(final_doi, stash_wrapper)

          sword_packager.submit(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource, tenant: tenant)
          se_resource
        end

        def update_ezid(final_doi, stash_wrapper)
          dcs_resource = stash_wrapper.datacite_resource
          dcs3_xml = dcs_resource.write_xml(mapping: :datacite_3)
          landing_url = tenant.landing_url("/stash/dataset/#{final_doi}")
          ezid_client.update_metadata(final_doi, dcs3_xml, landing_url)
          dcs_resource
        end

        def replace_existing_resource(se_resource, stash_wrapper, existing_resource)
          new_doi_value = existing_resource.identifier_value
          wrapper_id_value = se_resource.identifier_value
          log.info "Previously migrated record with DOI: #{new_doi_value} for #{se_resource.identifier_type}: #{wrapper_id_value}"

          update_se_identifiers(se_resource, wrapper_id_value, new_doi_value)
          update_dcs_identifiers(stash_wrapper, wrapper_id_value, new_doi_value)

          se_resource.user_id = existing_resource.user_id
          se_resource.download_uri = existing_resource.download_uri
          se_resource.update_uri = existing_resource.update_uri

          existing_resource.destroy

          id_for(new_doi_value)
        end

        def build_se_resource(stash_wrapper, user_uid)
          dcs_resource = stash_wrapper.datacite_resource
          builder = StashDatacite::ResourceBuilder.new(
            user_id: user_id_for(user_uid),
            dcs_resource: dcs_resource,
            stash_files: stash_wrapper.stash_files,
            upload_date: stash_wrapper.version_date
          )
          builder.build
        end

        def user_id_for(user_uid)
          user = StashEngine::User.find_by(uid: user_uid)
          raise "No user found for #{user_uid}" unless user
          user.id
        end

        def alt_ident_for(se_resource)
          se_ident = se_resource.identifier
          wrapper_id_value = se_ident.identifier
          wrapper_doi = id_for(wrapper_id_value)
          StashDatacite::AlternateIdentifier.find_by(alternate_identifier: wrapper_doi, alternate_identifier_type: MIGRATED_FROM)
        end

        def migrate_test_record(stash_wrapper, se_resource)
          se_ident = se_resource.identifier
          wrapper_id_value = se_ident.identifier

          new_doi = ezid_client.mint_id
          new_doi_value = new_doi.match(Datacite::Mapping::DOI_PATTERN)[0]
          log.warn "Minted new DOI: #{new_doi_value} for #{se_ident.identifier_type}: #{wrapper_id_value}"

          update_se_identifiers(se_resource, wrapper_id_value, new_doi_value)
          update_dcs_identifiers(stash_wrapper, wrapper_id_value, new_doi_value)

          new_doi
        end

        def update_se_identifiers(se_resource, wrapper_id_value, new_doi_value)
          se_ident = se_resource.identifier
          return if se_ident.identifier == new_doi_value

          se_ident.identifier = new_doi_value
          se_ident.save
          se_resource_id = se_resource.id
          alt_ident = StashDatacite::AlternateIdentifier.create(
            resource_id: se_resource_id,
            alternate_identifier_type: MIGRATED_FROM,
            alternate_identifier: id_for(wrapper_id_value)
          )
          log.info "Created alternate identifier #{alt_ident.id} with type '#{MIGRATED_FROM}' and value #{id_for(wrapper_id_value)} for resource #{se_resource_id}"
        end

        def id_for(id_value)
          if (match_data = Datacite::Mapping::DOI_PATTERN.match(id_value))
            "doi:#{match_data[0]}"
          else
            id_value
          end
        end

        def update_dcs_identifiers(stash_wrapper, wrapper_id_value, new_doi_value)
          dcs_resource = stash_wrapper.datacite_resource
          dcs_ident = dcs_resource.identifier
          return if dcs_ident.value == new_doi_value

          dcs_ident.value = new_doi_value
          dcs_resource.alternate_identifiers << Datacite::Mapping::AlternateIdentifier.new(
            type: MIGRATED_FROM,
            value: id_for(wrapper_id_value)
          )
        end

      end
    end
  end
end
