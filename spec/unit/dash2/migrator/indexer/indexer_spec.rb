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

          attr_reader :importer
          attr_reader :wrappers
          attr_reader :uids
          attr_reader :records

          before(:each) do

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

            doi_updater = instance_double(Importer::DOIUpdater)
            allow(Importer::DOIUpdater).to receive(:new).with(
              ezid_client: ezid_client,
              tenant: tenant,
              mint_dois: true
            ).and_return(doi_updater)

            sword_client = instance_double(Stash::Sword::Client)
            allow(Stash::Sword::Client).to receive(:new).with(sword_params).and_return(sword_client)

            sword_packager = instance_double(Importer::SwordPackager)
            allow(Importer::SwordPackager).to receive(:new).with(
              sword_client: sword_client,
              create_placeholder_files: true
            ).and_return(sword_packager)

            @importer = instance_double(Importer::Importer)
            allow(Importer::Importer).to receive(:new).with(
              doi_updater: doi_updater,
              sword_packager: sword_packager,
              tenant: tenant
            ).and_return(importer)

            @wrappers = Array.new(3) do |i|
              wrapper = instance_double(Stash::Wrapper::StashWrapper)
              sw_ident = Stash::Wrapper::Identifier.new(type: Stash::Wrapper::IdentifierType::DOI, value: "10.123/#{i}")
              allow(wrapper).to receive(:identifier).and_return(sw_ident)
              wrapper
            end
            @uids = Array.new(3) { |i| "user#{i}@example.edu" }
            @records = wrappers.zip(uids).map do |wrapper, uid|
              record = instance_double(Harvester::MerrittAtomHarvestedRecord)
              allow(record).to receive(:as_wrapper).and_return(wrapper)
              allow(record).to receive(:user_uid).and_return(uid)
              record
            end
          end

          it 'indexes' do
            allow(ActiveRecord::Base).to receive(:connection)
            allow(ActiveRecord::Base).to(receive(:transaction)) { |_args, &block| block.call }

            wrappers.zip(uids).each do |wrapper, uid|
              expect(importer).to receive(:import).with(stash_wrapper: wrapper, user_uid: uid)
            end
            indexer.index(records)
          end

          it 'establishes a connection' do
            expect(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::ConnectionNotEstablished)
            expect(ActiveRecord::Base).to receive(:establish_connection).with(indexer.db_config)
            allow(ActiveRecord::Base).to(receive(:transaction)) { |_args, &block| block.call }
            allow(importer).to receive(:import)
            indexer.index([records[0]])
          end
        end
      end
    end
  end
end
