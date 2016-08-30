require 'db_spec_helper'

module Dash2
  module Migrator
    describe Migrationator do

      attr_reader :user_uid

      before(:all) do
        @user_uid = 'lmuckenhaupt-ucop@ucop.edu'
      end

      before(:each) do
        @user = StashEngine::User.create(
          uid: user_uid,
          first_name: 'Lisa',
          last_name: 'Muckenhaupt',
          email: 'lmuckenhaupt@ucop.edu',
          provider: 'developer',
          tenant_id: 'ucop'
        )
        allow_any_instance_of(Dash2::Migrator::Harvester::MerrittAtomHarvestedRecord).to receive(:user_uid) { user_uid }

        @ezid_client = instance_double(StashEzid::Client)
        allow(@ezid_client).to receive(:mint_id) do
          time = Time.now
          @last_doi = "doi:10.5072/FK#{time.to_i}.#{time.nsec}"
        end
        allow(StashEzid::Client).to receive(:new) { @ezid_client }

        receipt = instance_double(Stash::Sword::DepositReceipt)
        allow(receipt).to(receive(:em_iri)) { "http://example.org/#{@last_doi}/em" }
        allow(receipt).to(receive(:edit_iri)) { "http://example.org/#{@last_doi}/edit" }

        @sword_client = instance_double(Stash::Sword::Client)
        allow(@sword_client).to receive(:create) { receipt }
        allow(Stash::Sword::Client).to receive(:new) { @sword_client }
      end

      it 'harvests and imports' do
        migrator = Migrationator.from_file('spec/data/migrator-full.yml')
        migrator.migrate!
        expect(StashEngine::Resource.count).to eq(47)
      end

    end
  end
end
