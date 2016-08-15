require 'db_spec_helper'
require 'stash/harvester_app'

module Stash
  module HarvesterApp
    describe Application do

      attr_reader :user_uid

      before(:all) do
        @user_uid = 'lmuckenhaupt-dataone@ucop.edu'
      end

      before(:each) do
        @user = StashEngine::User.create(
            uid: user_uid,
            first_name: 'Lisa',
            last_name: 'Muckenhaupt',
            email: 'lmuckenhaupt@example.org',
            provider: 'developer',
            tenant_id: 'dataone'
        )
        allow_any_instance_of(Dash2::Migrator::MerrittAtomHarvestedRecord).to receive(:user_uid) { user_uid }

        @ezid_client = instance_double(StashEzid::Client)
        allow(@ezid_client).to receive(:mint_id) {
          time = Time.now
          "doi:10.5072/FK#{time.to_i}.#{time.nsec}"
        }
        allow(StashEzid::Client).to receive(:new) { @ezid_client }

        @sword_client = instance_double(Stash::Sword::Client)
        allow(@sword_client).to receive(:create) do |doi, _zipfile|
          receipt = instance_double(Stash::Sword::DepositReceipt)
          allow(receipt).to receive(:em_iri) { "http://example.org/#{doi}/em" }
          allow(receipt).to receive(:edit_iri) { "http://example.org/#{doi}/edit" }
        end
        allow(Stash::Sword::Client).to receive(:new) { @sword_client }
      end

      it 'harvests and imports' do
        config_file = 'config/migrator-dataone.yml'
        app = Stash::HarvesterApp::Application.with_config_file(config_file)
        app.start

        expect(StashEngine::Resource.count).to eq(17)
      end
    end
  end
end
