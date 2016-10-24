require 'logger'
require 'stash_engine'
require 'dash2/migrator/importer/sword_packager'

module StashEngine
  class Resource < ActiveRecord::Base

    def first_alternate_identifier(type:)
      alternate_identifiers
        .where(alternate_identifier_type: type)
        .first
    end

    def first_identical_resource
      identical_resources.first
    end

    def identical_resources
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

        def mint_doi_for(stash_wrapper:)
          raise ArgumentError, "Wrong identifier type; expected ARK, was #{}" unless stash_wrapper.identifier.type == Stash::Wrapper::IdentifierType::ARK
          ark = stash_wrapper.identifier.value
          new_doi = ezid_client.mint_id
          log.warn "Minted new DOI: #{new_doi} for ARK: #{ark}"
        end

        def import_to_stash(stash_wrapper:, user_uid:)
          se_resource = build_se_resource(stash_wrapper, user_uid)
          se_ident = se_resource.identifier

          old_doi_value = se_ident.identifier
          old_doi = "doi:#{old_doi_value}"

          new_doi = ezid_client.mint_id
          new_doi_value = new_doi.match(Datacite::Mapping::DOI_PATTERN)[0]
          log.warn "Minted new DOI: #{new_doi} for #{se_ident.identifier_type}: #{old_doi_value}"

          se_ident.identifier = new_doi_value
          se_ident.save
          alt_ident = StashDatacite::AlternateIdentifier.create(
            resource_id: se_resource.id,
            alternate_identifier_type: MIGRATED_FROM,
            alternate_identifier: old_doi
          )
          log.info "Created alternate identifier #{alt_ident.id} with type '#{MIGRATED_FROM}' and value #{old_doi} for resource #{se_resource.id}"

          dcs_resource = stash_wrapper.datacite_resource
          dcs_resource.identifier.value = new_doi_value
          dcs_resource.alternate_identifiers << Datacite::Mapping::AlternateIdentifier.new(
            type: MIGRATED_FROM,
            value: old_doi
          )

          dcs3_xml = dcs_resource.write_xml(mapping: :datacite_3)
          landing_url = tenant.landing_url("/stash/dataset/#{new_doi}")
          ezid_client.update_metadata(new_doi, dcs3_xml, landing_url)

          sword_packager.submit(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource, tenant: tenant)
          se_resource
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
      end
    end
  end
end
