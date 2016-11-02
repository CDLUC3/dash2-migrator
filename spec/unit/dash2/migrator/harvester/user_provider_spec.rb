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
            expect(users_by_id.size).to eq(106)
          end
        end

        describe '#dash1_user_id_for' do
          it 'maps the user IDs' do
            found = {}
            missing = []
            records.each do |r|
              dash1_user_id = user_provider.dash1_user_id_for(local_id: r.local_id, title: r.title)
              if dash1_user_id
                found[r.ark] = dash1_user_id
              else
                missing << r
              end
            end
            expect(found.size).to eq(130)
            expect(missing.size).to eq(117)
          end
        end
      end
    end
  end
end
