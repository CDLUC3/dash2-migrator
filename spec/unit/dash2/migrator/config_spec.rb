require 'spec_helper'

module Dash2
  module Migrator
    describe Config do
      describe '#from_file' do

        attr_reader :config

        before(:all) do
          @config = Stash::Config.from_file('config/migrator-dataone.yml')
        end

        it 'parses a config file' do
          expect(config).to be_a(Stash::Config)
        end

        it 'creates a metadata mapper' do
          expect(config.metadata_mapper).to be_a(Stash::Indexer::MetadataMapper)
        end

        it 'creates a working index config' do
          index_config = config.index_config
          expect(index_config).to be_a(Dash2IndexConfig)
          expect(index_config.db_config_path).to eq(File.absolute_path('config/database.yml'))
          expect(index_config.id_mode).to eq(IDMode::ALWAYS_MINT)
          expected_ezid_config = {
              shoulder: 'doi:10.5072/FK2',
              account: 'apitest',
              password: 'apitest',
              id_scheme: 'doi',
              owner: nil
          }
          expect(index_config.ezid_config).to eq(expected_ezid_config)

          indexer = index_config.create_indexer(config.metadata_mapper)
          expect(indexer).to be_a(Dash2::Migrator::Dash2Indexer)
          expect(indexer.ezid_client).to be_a(StashEzid::Client)
        end

        it 'creates a source config' do
          source_config = config.source_config
          expect(source_config).to be_a(MerrittAtomSourceConfig)
          expect(source_config.feed_uri).to eq(URI("https://#{source_config.username}:#{source_config.password}@merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd"))
          expect(source_config.tenant_path).to eq(File.absolute_path('config/tenants/dataone.yml'))
        end
      end
    end
  end
end
