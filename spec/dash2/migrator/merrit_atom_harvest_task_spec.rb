require 'spec_helper'
require 'webmock/rspec'

module Dash2
  module Migrator
    describe MerrittAtomHarvestTask do

      attr_reader :feed_uri
      attr_reader :page2_uri
      attr_reader :feed
      attr_reader :page2

      attr_reader :task

      before(:each) do
        @feed_uri = 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd'
        @page2_uri = 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd&page=2'
        @feed = File.read('spec/data/ark:-13030-m5709fmd.atom').freeze
        @page2 = File.read('spec/data/ark:-13030-m5709fmd&page=2.atom').freeze

        @tenant_path = File.absolute_path('config/tenants/dataone.yml')
        @config = MerrittAtomSourceConfig.new(tenant_path: @tenant_path, feed_uri: @feed_uri)
        @task = MerrittAtomHarvestTask.new(config: @config)
      end

      describe '#harvest_records' do
        it 'gets the Merritt Atom feed' do
          stub_request(:get, feed_uri).to_return(body: feed)
          task.harvest_records

          expect(a_request(:get, feed_uri)).to have_been_made
        end

        it 'gets all entries' do
          stub_request(:get, feed_uri).to_return(body: feed)
          stub_request(:get, page2_uri).to_return(body: page2)

          entries = task.harvest_records.to_a
          expect(entries.size).to eq(17)
        end

        it 'is lazy' do
          stub_request(:get, feed_uri).to_return(body: feed)
          stub_request(:get, page2_uri).to_return(body: page2)

          records = task.harvest_records

          expect(a_request(:get, feed_uri)).to have_been_made
          expect(a_request(:get, page2_uri)).not_to have_been_made

          records.to_a

          expect(a_request(:get, page2_uri)).to have_been_made
        end
      end
    end
  end
end
