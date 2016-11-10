require 'db_spec_helper'

module Dash2
  module Migrator
    module Harvester
      describe UserProvider do
        attr_reader :records
        attr_reader :records_by_ark
        attr_reader :user_provider

        ARKS_LOCALIDS_TITLES = 'spec/data/harvester/arks_localids_titles.txt'.freeze

        before(:each) do
          @records = UserProvider.parse_tsv(ARKS_LOCALIDS_TITLES).freeze
          @records_by_ark = records.map { |r| [r.ark, r] }.to_h.freeze
          @user_provider = UserProvider.new('config/dash1_records_users.txt')
        end

        describe '#stash_user_id_for' do
          it 'maps the users' do
            records.each do |record|
              stash_user_id = user_provider.stash_user_id_for(record)
              expect(stash_user_id).not_to be_nil
            end
            expect(StashEngine::User.count).to eq(72)
          end

          it 'doesn\'t replace existing users' do
            uid = '101663810912298466931'
            id = StashEngine::User.create(
              uid: uid,
              first_name: 'Dash',
              last_name: 'Admin',
              email: 'cdluc3@gmail.com',
              provider: 'google_oauth2',
              tenant_id: 'dataone',
              oauth_token: '12345'
            ).id
            dataup_records = records.select { |r| r.ark.start_with?('ark:/90135/') }
            expect(dataup_records.size).to eq(90) # just to be sure
            dataup_records.each do |record|
              stash_user_id = user_provider.stash_user_id_for(record)
              expect(stash_user_id).to eq(id)
            end
          end
        end
      end
    end
  end
end
