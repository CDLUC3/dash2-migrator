require 'active_support'
require 'logger'

module Dash2
  module Migrator
    module Importer

      class Importer

        attr_reader :sword_packager
        attr_reader :doi_updater
        attr_reader :tenant

        def initialize(doi_updater:, sword_packager:, tenant:)
          @doi_updater = doi_updater
          @sword_packager = sword_packager
          @tenant = tenant
        end

        def log
          Stash::Harvester.log
        end

        def import(stash_wrapper:, user_uid:)
          previously_migrated = previously_migrated(stash_wrapper)
          return previously_migrated if previously_migrated

          dcs_resource = stash_wrapper.datacite_resource
          se_resource = build_se_resource(stash_wrapper, dcs_resource, user_uid)

          # TODO: stop doing this once we have Datacite 3/4 sorted out
          dcs_resource.funding_references = [] # EZID doesn't like fundingReferences

          # TODO: stop passing dcs_resource around separately
          doi_updater.update(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource)

          # TODO: stop needing to re-inject this
          stash_wrapper.datacite_resource = dcs_resource

          sword_packager.submit(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource, tenant: tenant)
          se_resource
        end

        private

        def previously_migrated(stash_wrapper)
          old_doi = "doi:#{stash_wrapper.identifier.value}"
          migration_record = StashDatacite::AlternateIdentifier.find_by(alternate_identifier: old_doi)
          previously_migrated = (StashEngine::Resource.find_by(id: migration_record.resource_id) if migration_record)
          log_previously_migrated(stash_wrapper, previously_migrated) if previously_migrated
          previously_migrated
        end

        def log_previously_migrated(stash_wrapper, previously_migrated)
          old_doi_value = stash_wrapper.identifier.value
          new_doi = previously_migrated.identifier.identifier
          resource_id = previously_migrated.id
          log.info("Skipping already migrated DOI #{old_doi_value} (migrated to #{new_doi}, resource ID #{resource_id})")
        end

        def user_id_for(user_uid)
          user = StashEngine::User.find_by(uid: user_uid)
          raise "No user found for #{user_uid}" unless user
          user.id
        end

        def build_se_resource(stash_wrapper, dcs_resource, user_uid)
          builder = StashDatacite::ResourceBuilder.new(
            user_id: user_id_for(user_uid),
            dcs_resource: dcs_resource,
            stash_files: stash_wrapper.stash_files,
            upload_date: stash_wrapper.version_date
          )
          builder.build
        end
      end
    end
  end
end