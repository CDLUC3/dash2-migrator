require 'spec_helper'

require 'webmock/rspec'

module Dash2
  module Migrator
    describe 'MerrittAtomHarvestedRecord' do

      attr_reader :record
      attr_reader :wrapper

      before(:all) do
        WebMock.disable_net_connect!
      end

      before(:each) do
        mrt_mom_uri = 'https://merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr3rg6g/1/system%2Fmrt-mom.txt'
        stub_request(:get, mrt_mom_uri).to_return(body: File.read('spec/data/mrt-mom.txt'))

        datacite_uri = 'https://merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr3rg6g/1/producer%2Fmrt-datacite.xml'
        stub_request(:get, datacite_uri).to_return(body: File.read('spec/data/mrt-datacite.xml'))

        feed_uri = 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd'
        entry_xml = File.read('spec/data/entry-r3rg6g.xml')
        entry = RSS::Parser.parse(entry_xml, false).items[0]
        @record = MerrittAtomHarvestedRecord.new(feed_uri, entry)
        @wrapper = record.as_wrapper
      end

      describe '#identifier' do
        it 'extracts the identifier' do
          expect(record.identifier).to eq('http://n2t.net/ark:/c5146/r3rg6g')
        end

      end

      describe '#stash_wrapper' do
        it 'uses basic-auth credentials from the tenant file'

        it 'creates a StashWrapper' do
          expect(wrapper).to be_a(Stash::Wrapper::StashWrapper)
        end
      end
    end
  end
end
