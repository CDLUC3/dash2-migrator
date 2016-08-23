require 'spec_helper'

module Dash2
  module Migrator
    module Importer
      describe SwordPackager do

        describe '#initialize' do
          it 'requires a client' do
            expect { SwordPackager.new }.to raise_error(ArgumentError)
          end

          it 'rejects a nil client' do
            expect { SwordPackager.new(sword_client: nil) }.to raise_error(ArgumentError)
          end

          it 'accepts a Stash::Sword::Client' do
            client = Stash::Sword::Client.new(
              collection_uri: 'http://uc3-mrtsword-dev.cdlib.org:39001/mrtsword/collection/demo_open_context',
              username: 'dataone_dash_submitter',
              password: 'w2NnJ8qj'
            )
            expect(SwordPackager.new(sword_client: client).sword_client).to be(client)
          end

          it 'accepts a mock Stash::Sword::Client' do
            client = instance_double(Stash::Sword::Client)
            expect(SwordPackager.new(sword_client: client).sword_client).to be(client)
          end
        end

      end
    end
  end
end
