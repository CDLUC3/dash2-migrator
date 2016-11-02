require 'spec_helper'

module Dash2
  module Migrator
    describe MigrationJob do

      EXPECTED_SOURCES = [
        {
          tenant_path: 'config/tenants/ucb.yml',
          feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5q82t8x'
        },
        {
          tenant_path: 'config/tenants/uci.yml',
          feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5fr19qh'
        },
        {
          tenant_path: 'config/tenants/ucla.yml',
          feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5tm8r6v'
        },
        {
          tenant_path: 'config/tenants/ucm.yml',
          feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5sv2b3c'
        },
        {
          tenant_path: 'config/tenants/ucsc.yml',
          feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5t16hvv'
        },
        {
          tenant_path: 'config/tenants/ucsf.yml',
          feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m52j8gvj'
        },
        {
          tenant_path: 'config/tenants/ucsf.yml',
          feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5ng4nz1'
        },
        {
          tenant_path: 'config/tenants/ucop.yml',
          feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5v13jxb'
        },
        {
          tenant_path: 'config/tenants/dataone.yml',
          feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd'
        }
      ].freeze

      EXPECTED_DB_PATH = 'spec/data/indexer/database.yml'.freeze
      EXPECTED_TENANT_OVERRIDE = 'config/tenants/ucop.yml'.freeze

      attr_reader :job

      before(:each) do
        @job = MigrationJob.from_file('spec/data/migrate-all.yml')
      end

      describe '#initialize' do
        it 'reads all sources' do
          expect(job.sources).to eq(EXPECTED_SOURCES)
        end

        it 'reads the index DB config path' do
          expect(job.index_db_config_path).to eq(EXPECTED_DB_PATH)
        end

        it 'reads the tenant override' do
          expect(job.index_tenant_override).to eq(EXPECTED_TENANT_OVERRIDE)
        end

        it 'reads the environment' do
          expect(job.env_name).to eq('test')
        end

        it 'reads the users path' do
          expect(job.users_path).to eq('config/dash1_records_users.txt')
        end
      end

      describe '#migrate' do
        it 'migrates each source' do
          user_provider = instance_double(Dash2::Migrator::Harvester::UserProvider)
          users_path = File.absolute_path('config/dash1_records_users.txt')
          allow(Dash2::Migrator::Harvester::UserProvider).to receive(:new).with(users_path).and_return(user_provider)

          EXPECTED_SOURCES.each do |source|
            source_config = instance_double(Harvester::MerrittAtomSourceConfig)
            expect(Harvester::MerrittAtomSourceConfig).to receive(:new).with(
              tenant_path: source[:tenant_path],
              feed_uri: source[:feed_uri],
              user_provider: user_provider,
              env_name: 'test'
            ).and_return(source_config)

            index_config = instance_double(Indexer::IndexConfig)
            expect(Indexer::IndexConfig).to receive(:new).with(
              db_config_path: EXPECTED_DB_PATH,
              tenant_path: EXPECTED_TENANT_OVERRIDE,
              user_provider: user_provider
            ).and_return(index_config)

            migrator_config = instance_double(MigratorConfig)
            expect(MigratorConfig).to receive(:new).with(
              source_config: source_config,
              index_config: index_config
            ).and_return(migrator_config)

            harvester_app = instance_double(Stash::HarvesterApp::Application)
            expect(Stash::HarvesterApp::Application).to receive(:with_config).with(migrator_config).and_return(harvester_app)
            expect(harvester_app).to receive(:start)
          end

          job.migrate!
        end
      end
    end
  end
end
