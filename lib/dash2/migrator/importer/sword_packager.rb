require 'stash/sword'
require 'datacite/mapping'
require 'stash/wrapper'
require 'stash_engine'
require 'dash2/migrator/importer/zip_package_builder'
require 'dash2/migrator/importer/sword_submit_task'

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

        # TODO: replace SwordCreator/SwordUpdater with SubmissionTask or similar
        # @return [String] the path to the submitted zipfile
        def submit(stash_wrapper:, dcs_resource:, se_resource:, tenant:) # TODO: stop passing dcs_resource
          package_builder = make_package_builder(dcs_resource, se_resource, stash_wrapper, tenant)
          zipfile = package_builder.make_package
          SwordSubmitTask.new(se_resource: se_resource, zipfile: zipfile, sword_client: sword_client).submit!
        end

        private

        def make_package_builder(dcs_resource, se_resource, stash_wrapper, tenant) # TODO: stop passing dcs_resource
          ZipPackageBuilder.new(
            stash_wrapper: stash_wrapper,
            dcs_resource: dcs_resource,
            se_resource: se_resource,
            tenant: tenant,
            create_placeholder_files: create_placeholder_files
          )
        end
      end

    end
  end
end
