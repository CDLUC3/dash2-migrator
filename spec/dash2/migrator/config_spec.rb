require 'spec_helper'

module Dash2
  module Migrator
    describe Config do
      describe '#from_file' do
        it 'parses a config file' do
          path = 'spec/data/stash-migrator.yml'
          config = Config.from_file(path)
          expect(config).to be_a(Config)
        end
      end
    end
  end
end
