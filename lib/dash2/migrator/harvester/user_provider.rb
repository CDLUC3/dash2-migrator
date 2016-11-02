require 'csv'
require 'ostruct'

module Dash2
  module Migrator
    module Harvester
      class UserProvider

        attr_reader :users_by_id

        def initialize(dash1_records_users_path)
          dash1_records_users = UserProvider.parse_tsv(dash1_records_users_path)
          users_by_id = {}
          dash1_records_users.each do |r|
            user_id = r.user_id.to_i
            users_by_id[user_id] = extract_user(r) unless users_by_id[user_id]
          end

          @users_by_id = users_by_id.sort.to_h.freeze
        end

        def extract_dataset(r)
          dataset_hash = {
            local_id: r.local_id,
            title: r.title,
            campus: r.campus
          }
          OpenStruct.new(dataset_hash)
        end

        def extract_user(r)
          user_hash = {
            id: r.user_id.to_i,
            first_name: r.first_name,
            last_name: r.last_name,
            email: r.email,
            uid: r.uid,
            provider: r.provider,
            oauth_token: r.oauth_token,
            tenant_id: r.campus
          }
          OpenStruct.new(user_hash)
        end

        def self.parse_tsv(path)
          records = []
          File.open(path) do |f|
            header_line = f.gets
            headers = header_line.strip.split("\t").map(&:to_sym)
            f.each do |line|
              cells = line.split("\t").map { |v| normalize_cell(v) }
              record_hash = Hash[headers.zip(cells)]
              records << OpenStruct.new(record_hash)
            end
          end
          records
        end

        def self.normalize_cell(v)
          return nil unless v
          value = v.strip
          return nil if value == 'nil'
          return nil if value == ''
          value
        end
      end
    end
  end
end
