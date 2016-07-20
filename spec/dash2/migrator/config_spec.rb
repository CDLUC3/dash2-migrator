require 'spec_helper'

module Dash2
  module Migrator
    describe Config do
      describe '#from_file' do
        it 'parses a config file' do
          path = 'spec/data/stash-migrator.yml'
          config = Config.from_file(path)
          expect(config).to be_a(Config)

          expect(config.connection_info).to be_a(Hash)

          indexer = config.indexer
          expect(indexer).to be_a(Stash::Indexer::Solr::SolrIndexer)
          expect(indexer.metadata_mapper).to be_a(Stash::Indexer::DataciteGeoblacklight::Mapper)
        end
      end
    end
  end
end
