require 'spec_helper'

require 'stash/config'
require 'ar_persistence_config'

module Dash2
  module Migrator
    describe Config do
      describe '#from_file' do
        it 'parses a config file' do
          path = 'config/stash-migrator.yml'
          config = Stash::Config.from_file(path)
          expect(config).to be_a(Stash::Config)

          index_config = config.index_config
          expect(index_config).to be_a(Dash2IndexConfig)
          expect(index_config.db_config_path).to eq(File.absolute_path('config/database.yml'))
        end
      end
    end
  end
end
