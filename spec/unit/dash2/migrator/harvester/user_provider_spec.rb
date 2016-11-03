require 'spec_helper'

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

        describe '#parse_tsv' do
          it 'parses' do
            expect(records.size).to eq(247)
            records.each do |r|
              expect(r).to respond_to(:tenant)
              expect(r).to respond_to(:ark)
              expect(r).to respond_to(:local_id)
              expect(r).to respond_to(:title)
            end
          end

          it 'round-trips' do
            expected = File.read(ARKS_LOCALIDS_TITLES).gsub('nil', '')
            actual = "tenant\tark\tlocal_id\ttitle\n"
            records.each do |r|
              line = "#{r.tenant}\t#{r.ark}\t#{r.local_id}\t#{r.title}"
              actual << line
              actual << "\n"
            end
            expect(actual).to eq(expected)
          end
        end

        describe '#users_by_id' do
          it 'extracts the users' do
            users_by_id = user_provider.users_by_id
            expect(users_by_id.size).to eq(110)
          end
        end

        describe '#dash1_user_for' do
          it 'maps the users' do
            aggregate_failures('all datasets') do
              found = {}
              records.each do |r|
                dash1_user = user_provider.dash1_user_for(r)
                expect(dash1_user).not_to be_nil, "No user found for #{r.ark} (#{r.local_id || 'nil'}): '#{r.title}'"
                found[r.ark] = dash1_user
              end
              expect(found.size).to eq(247)
              unique_users = found.values.uniq
              expect(unique_users.size).to eq(72)
            end
          end
        end

        # describe '#dash1_user_for' do
        #   it 'maps the users' do
        #     found = {}
        #     missing = []
        #     records.each do |record|
        #       dash1_user = user_provider.dash1_user_for(record)
        #       if dash1_user
        #         found[record.ark] = dash1_user
        #       else
        #         missing << record
        #       end
        #     end
        #     expect(missing.size).to eq(117)
        #     expect(found.size).to eq(130)
        #     unique_users = found.values.uniq
        #     expect(unique_users.size).to eq(68)
        #
        #     laurance = user_provider.users_by_id[149]
        #     expect(laurance).not_to be_nil
        #     expect(laurance.last_name).to eq('Laurance') # just to be sure
        #
        #     swanson = user_provider.users_by_id[108]
        #     expect(swanson).not_to be_nil
        #     expect(swanson.email).to eq('swanson-hysell@berkeley.edu') # just to be sure
        #
        #     lin = OpenStruct.new(
        #       id: 137,
        #       first_name: 'Emily',
        #       last_name: 'Lin',
        #       email: 'elin@ucmerced.edu',
        #       uid: 'elin@ucmerced.edu',
        #       provider: 'shibboleth',
        #       oauth_token: nil,
        #       tenant_id: 'ucm'
        #     )
        #
        #     tangherlini = OpenStruct.new(
        #       id: 1001,
        #       first_name: 'Timothy',
        #       last_name: 'Tangherlini',
        #       email: 'tango@humnet.ucla.edu',
        #       uid: 'tango@humnet.ucla.edu',
        #       provider: 'shibboleth',
        #       oauth_token: nil,
        #       tenant_id: 'ucla'
        #     )
        #
        #     zangle = OpenStruct.new(
        #       id: 1002,
        #       first_name: 'Thomas',
        #       last_name: 'Zangle',
        #       email: 'tzangle@ucla.edu',
        #       uid: 'tzangle@ucla.edu',
        #       provider: 'shibboleth',
        #       oauth_token: nil,
        #       tenant_id: 'ucla'
        #     )
        #
        #     # id	first_name	last_name	email	uid	provider	oauth_token	created_at	updated_at	tenant_id	orcid
        #     # 122	CDL	UC3	cdluc3@gmail.com	101663810912298466931	google_oauth2	ya29.CjWKA7pjbDhmB1Bpyk0OMBrz9K_1WEwSqIzhzSOxGAafHFICZZkCH51k22gipJwjLXCpkxw8Og	2016-11-03 21:19:23	2016-11-03 21:19:23	dataone	0
        #
        #     cdluc3 = OpenStruct.new(
        #       id: 1003,
        #       first_name: 'Dash',
        #       last_name: 'Admin',
        #       email: 'cdluc3@gmail.com',
        #       uid: '101663810912298466931',
        #       provider: 'google_oauth2',
        #       oauth_token: 'ya29.CjWKA7pjbDhmB1Bpyk0OMBrz9K_1WEwSqIzhzSOxGAafHFICZZkCH51k22gipJwjLXCpkxw8Og',
        #       tenant_id: 'dataone'
        #     )
        #
        #     count = 0
        #     missing.each do |record|
        #       count += 1
        #       record_id = 1000 + count
        #       title = record.title
        #       title_count = 1
        #       local_id = nil
        #
        #       user = if record.ark.start_with?('ark:/b7272/q6')
        #                laurance
        #              elsif record.ark == 'ark:/b6071/z7wc73'
        #                lin
        #              elsif record.ark == 'ark:/b5068/d1wc7k'
        #                tangherlini
        #              elsif record.ark == 'ark:/b5068/d1rp49'
        #                zangle
        #              elsif record.ark == 'ark:/b6078/d17g6j' || record.ark == 'ark:/b6078/d1c88g'
        #                swanson
        #              elsif record.ark.start_with?('ark:/90135/')
        #                cdluc3
        #              else
        #                fail "No known user for #{record.ark}"
        #              end
        #       user_id = user.id
        #       campus = user.tenant_id
        #       first_name = user.first_name
        #       last_name = user.last_name
        #       email = user.email
        #       uid = user.uid
        #       provider = user.provider
        #       oauth_token = user.oauth_token || 'NULL'
        #
        #       puts "#{record_id}\t#{title}\t#{title_count}\t#{local_id}\t#{user_id}\t#{campus}\t#{first_name}\t#{last_name}\t#{email}\t#{uid}\t#{provider}\t#{oauth_token}"
        #     end
        #   end
        # end

      end
    end
  end
end
