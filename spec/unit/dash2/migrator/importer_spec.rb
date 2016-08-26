require 'spec_helper'

module Dash2
  module Migrator
    module Importer
      describe Importer do

        attr_reader :user_uid
        attr_reader :user_id

        attr_reader :doi_updater
        attr_reader :sword_packager
        attr_reader :tenant

        attr_reader :importer

        attr_reader :wrapper

        def old_doi_value
          @old_doi_value ||= wrapper.identifier.value
        end

        def old_doi
          @old_doi ||= "doi:#{old_doi_value}"
        end

        before(:all) do
          @user_uid = 'lmuckenhaupt-ucop@ucop.edu'
          @user_id = 17
        end

        before(:each) do
          user = instance_double(StashEngine::User)
          allow(user).to receive(:id).and_return(user_id)
          allow(StashEngine::User).to receive(:find_by).with(uid: user_uid).and_return(user)

          @doi_updater = instance_double(DOIUpdater)
          @sword_packager = instance_double(SwordPackager)
          @tenant = instance_double(StashEngine::Tenant)

          @importer = Importer.new(doi_updater: doi_updater, sword_packager: sword_packager, tenant: tenant)
          @wrapper = Stash::Wrapper::StashWrapper.parse_xml(File.read('spec/data/harvested-wrapper.xml'))
        end

        it 'imports' do
          allow(StashDatacite::AlternateIdentifier)
            .to receive(:find_by)
            .with(alternate_identifier: old_doi)
            .and_return(nil)

          builder = instance_double(StashDatacite::ResourceBuilder)
          se_resource = double(StashEngine::Resource)
          allow(builder).to receive(:build).and_return(se_resource)

          allow(StashDatacite::ResourceBuilder).to receive(:new).with(
            user_id: user_id,
            dcs_resource: wrapper.datacite_resource,
            stash_files: wrapper.stash_files,
            upload_date: wrapper.version_date
          ).and_return(builder)

          expect(doi_updater).to receive(:update).with(
            stash_wrapper: wrapper,
            dcs_resource: wrapper.datacite_resource,
            se_resource: se_resource
          ).ordered

          expect(sword_packager).to receive(:submit).with(
            stash_wrapper: wrapper,
            dcs_resource: wrapper.datacite_resource,
            se_resource: se_resource,
            tenant: tenant
          ).ordered

          imported = importer.import(stash_wrapper: wrapper, user_uid: user_uid)
          expect(imported).to be(se_resource)
        end

        it 'skips previously migrated records' do
          resource_id = 31
          alt_ident = double(StashDatacite::AlternateIdentifier)
          allow(alt_ident).to receive(:resource_id).and_return(resource_id)

          allow(StashDatacite::AlternateIdentifier)
            .to receive(:find_by)
            .with(alternate_identifier: old_doi)
            .and_return(alt_ident)

          migrated_ident = double(StashEngine::Identifier)
          allow(migrated_ident).to receive(:identifier).and_return('10.123/456')

          migrated_resource = instance_double(StashEngine::Resource)
          allow(migrated_resource).to receive(:identifier).and_return(migrated_ident)
          allow(migrated_resource).to receive(:id).and_return(23)

          allow(StashEngine::Resource).to receive(:find_by).with(id: resource_id).and_return(migrated_resource)

          imported = importer.import(stash_wrapper: wrapper, user_uid: user_uid)
          expect(imported).to be(migrated_resource)
        end

      end
    end
  end
end
