require 'db_spec_helper'

module Dash2
  module Migrator

    module Datacite::Mapping::ReadOnlyNodes
      def self.warn(warning)
        Stash::Harvester.log.warn(warning)
      end
    end

    describe MigrationJob do

      EXPECTED_RECORDS = 2

      attr_reader :user_uid
      attr_reader :last_doi

      before(:each) do
        @ezid_client = instance_double(StashEzid::Client)
        allow(@ezid_client).to receive(:mint_id) do
          time = Time.now
          @last_doi = "doi:10.5072/FK#{time.to_i}.#{time.nsec}"
        end
        allow(@ezid_client).to receive(:update_metadata)
        allow(StashEzid::Client).to receive(:new) { @ezid_client }

        receipt = instance_double(Stash::Sword::DepositReceipt)
        allow(receipt).to(receive(:em_iri)) { "http://example.org/#{@last_doi}/em" }
        allow(receipt).to(receive(:edit_iri)) { "http://example.org/#{@last_doi}/edit" }

        @sword_client = instance_double(Stash::Sword::Client)
        allow(@sword_client).to receive(:create) { receipt }
        allow(@sword_client).to receive(:collection_uri) { 'http://example.org/sword/my-collection' }
        allow(Stash::Sword::Client).to receive(:new) { @sword_client }
      end

      # https://merritt.cdlib.org/d/ark%3A%2Fb7941%2Fd11593/1/producer%2Fmrt-datacite.xml

      describe 'harvest and import' do
        attr_reader :config_file

        before(:each) do
          @config_file = 'config/migrate-lbnl.yml'
          migrator = MigrationJob.from_file(config_file)
          migrator.migrate!
        end

        it 'harvests and imports' do
          expect(StashEngine::Resource.count).to eq(EXPECTED_RECORDS)
        end

        it 'remigrates' do
          expect(@sword_client).to receive(:update).exactly(EXPECTED_RECORDS).times.and_return(200)
          migrator = MigrationJob.from_file(config_file)
          migrator.migrate!
          expect(StashEngine::Resource.count).to eq(EXPECTED_RECORDS)
        end
      end

    end
  end
end
