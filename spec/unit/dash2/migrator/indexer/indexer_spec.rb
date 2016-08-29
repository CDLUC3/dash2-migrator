require 'spec_helper'

module Dash2
  module Migrator
    module Indexer
      describe Indexer do

        attr_reader :indexer

        before(:each) do
          db_yml = 'spec/data/indexer/database.yml'
          tenant_yml = 'config/tenants/example.yml'
          config = IndexConfig.new(db_config_path: db_yml, tenant_path: tenant_yml)
          @indexer = config.create_indexer
        end

        describe '#demo_mode?' do
          it 'returns false for test' do
            expect(indexer.demo_mode?).to eq(true)
          end

          it 'returns true for production' do
            allow(Migrator).to receive(:production?).and_return(true)
            expect(indexer.demo_mode?).to eq(false)
          end
        end

        describe '#index' do
          it 'indexes' do
            sword_params = {
              collection_uri: 'http://sword-dev.example.org:39001/mrtsword/collection/test',
              username: 'test',
              password: 'test'
            }
            tenant = instance_double(StashEngine::Tenant)
            allow(tenant).to receive(:sword_params).and_return(sword_params)
            allow(StashEngine::Tenant).to receive(:new).with(indexer.tenant_config).and_return(tenant)

            ezid_params = {
              shoulder: 'doi:10.5072/FK2',
              account: 'test',
              password: 'test',
              id_scheme: 'doi',
              owner: nil
            }
            ezid_client = instance_double(StashEzid::Client)
            allow(StashEzid::Client).to receive(:new).with(ezid_params).and_return(ezid_client)

            doi_updater = instance_double(Dash2::Migrator::Importer::DOIUpdater)
            allow(Dash2::Migrator::Importer::DOIUpdater).to receive(:new).with(
              ezid_client: ezid_client,
              tenant: tenant,
              mint_dois: true
            ).and_return(doi_updater)

            sword_client = instance_double(Stash::Sword::Client)
            allow(Stash::Sword::Client).to receive(:new).with(sword_params).and_return(sword_client)

            sword_packager = instance_double(Dash2::Migrator::Importer::SwordPackager)
            allow(Dash2::Migrator::Importer::SwordPackager).to receive(:new).with(
              sword_client: sword_client,
              create_placeholder_files: true
            ).and_return(sword_packager)

            importer = instance_double(Dash2::Migrator::Importer::Importer)
            allow(Dash2::Migrator::Importer::Importer).to receive(:new).with(
              doi_updater: doi_updater,
              sword_packager: sword_packager,
              tenant: tenant
            ).and_return(importer)

            expect(indexer.importer).to be(importer) # just to be sure
          end
        end


      end
    end
  end
end
