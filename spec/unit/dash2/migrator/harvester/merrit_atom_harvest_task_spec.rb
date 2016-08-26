require 'spec_helper'
require 'webmock/rspec'
require 'base64'

module Dash2
  module Migrator
    module Harvester

      describe MerrittAtomHarvestTask do
        attr_reader :feed_uri
        attr_reader :page2_uri
        attr_reader :feed
        attr_reader :page2
        attr_reader :config
        attr_reader :task

        before(:each) do
          base_feed_uri = 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd'
          @tenant_path = File.absolute_path('config/tenants/example.yml')
          @config = MerrittAtomSourceConfig.new(tenant_path: @tenant_path, feed_uri: base_feed_uri, env_name: 'test')
          @task = MerrittAtomHarvestTask.new(config: @config)

          @feed_uri = base_feed_uri.sub('https://', "https://#{config.username}:#{config.password}@")
          @feed = File.read('spec/data/harvester/ark:-13030-m5709fmd.atom').freeze
          stub_request(:get, @feed_uri).to_return(body: feed)

          @page2_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd&page=2"
          @page2 = File.read('spec/data/harvester/ark:-13030-m5709fmd&page=2.atom').freeze
          stub_request(:get, page2_uri).to_return(body: page2)
        end

        describe '#harvest_records' do
          it 'gets the Merritt Atom feed' do
            task.harvest_records
            expect(a_request(:get, feed_uri)).to have_been_made
          end

          it 'gets all entries' do
            records_array = task.harvest_records.to_a
            expect(records_array.size).to eq(17)
          end

          it 'is lazy' do
            records = task.harvest_records
            expect(a_request(:get, page2_uri)).not_to have_been_made

            records.to_a
            expect(a_request(:get, page2_uri)).to have_been_made
          end

          it 'creates HarvestedRecords for all entries' do
            records = task.harvest_records.to_a

            expected_identifiers = %w(
              http://n2t.net/ark:/c5146/r3rg6g
              http://n2t.net/ark:/c5146/r31017
              http://n2t.net/ark:/c5146/r34s3v
              http://n2t.net/ark:/c5146/r3d59d
              http://n2t.net/ark:/c5146/r3np4v
              http://n2t.net/ark:/c5146/r3201j
              http://n2t.net/ark:/c5146/r39g6f
              http://n2t.net/ark:/c5146/r3pp45
              http://n2t.net/ark:/c5146/r3tg63
              http://n2t.net/ark:/c5146/r36p4t
              http://n2t.net/ark:/c5146/r3g591
              http://n2t.net/ark:/c5146/r3kw2j
              http://n2t.net/ark:/c5146/r3059p
              http://n2t.net/ark:/c5146/r33w26
              http://n2t.net/ark:/c5146/r3cc7d
              http://n2t.net/ark:/c5146/r3mw2v
              http://n2t.net/ark:/c5146/r3rp4s
            )

            identifiers = records.map(&:identifier)
            expect(identifiers).to eq(expected_identifiers)
          end
        end
      end
    end
  end
end
