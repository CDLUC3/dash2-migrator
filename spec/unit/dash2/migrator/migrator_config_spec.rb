require 'spec_helper'

module Dash2
  module Migrator
    describe MigratorConfig do

      describe '#initialize' do
        it 'accepts mock config objects' do
          source_config = instance_double(Harvester::MerrittAtomSourceConfig)
          index_config = instance_double(Indexer::IndexConfig)
          config = MigratorConfig.new(source_config: source_config, index_config: index_config)
          expect(config.source_config).to be(source_config)
          expect(config.index_config).to be(index_config)
        end

        it 'rejects a bad source_config' do
          source_config = Stash::Harvester::OAI::OAISourceConfig.allocate
          index_config = instance_double(Indexer::IndexConfig)
          expect do
            MigratorConfig.new(
              source_config: source_config,
              index_config: index_config
            )
          end.to raise_error(ArgumentError)
        end

        it 'rejects a bad index_config' do
          source_config = instance_double(Harvester::MerrittAtomSourceConfig)
          index_config = Stash::Indexer::Solr::SolrIndexConfig.allocate
          expect do
            MigratorConfig.new(
              source_config: source_config,
              index_config: index_config
            )
          end.to raise_error(ArgumentError)
        end
      end

      describe '#from_file' do
        it 'loads a configuration' do
          config = MigratorConfig.from_file('spec/data/migrator.yml')
          expect(config).to be_a(MigratorConfig)

          expect(config.source_config).to be_a(Harvester::MerrittAtomSourceConfig)
          expect(config.index_config).to be_a(Indexer::IndexConfig)
        end

        it 'instantiates a working HarvesterApp::Application' do
          config = MigratorConfig.from_file('spec/data/migrator.yml')
          app = Stash::HarvesterApp::Application.with_config(config)
          job = app.send(:create_job)
          expect(job).to be_a(Stash::HarvestAndIndexJob)
          expect(job.harvest_task).to be_a(Dash2::Migrator::Harvester::MerrittAtomHarvestTask)
          expect(job.indexer).to be_a(Dash2::Migrator::Indexer::Indexer)
        end
      end

      describe '#from_files' do
        it 'loads source and index configs separately' do
          config = MigratorConfig.from_files(source: 'spec/data/source-example.yml', index: 'spec/data/index-example.yml')
          app = Stash::HarvesterApp::Application.with_config(config)
          job = app.send(:create_job)
          expect(job).to be_a(Stash::HarvestAndIndexJob)
          expect(job.harvest_task).to be_a(Dash2::Migrator::Harvester::MerrittAtomHarvestTask)
          expect(job.indexer).to be_a(Dash2::Migrator::Indexer::Indexer)
        end
      end
    end
  end
end
