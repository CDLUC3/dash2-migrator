require 'csv'
require 'ostruct'
require 'stash_engine'

module Dash2
  module Migrator
    module Harvester
      class UserProvider

        attr_reader :users_path
        attr_reader :users_by_id
        attr_reader :user_ids_by_local_id
        attr_reader :user_ids_by_title

        def initialize(users_path)
          @users_path = users_path
          dash1_records_users = UserProvider.parse_tsv(users_path)
          @users_by_id = {}
          @user_ids_by_title = {}
          @user_ids_by_local_id = {}
          dash1_records_users.each do |record|
            user_id = record.user_id
            raise ArgumentError, "No user ID for record: #{record}" unless user_id
            users_by_id[user_id] = extract_user(record) unless users_by_id[user_id]
            record_local_id(user_ids_by_local_id, record)
            record_title(user_ids_by_title, record)
          end
        end

        def ensure_uid!(record)
          dash1_user = dash1_user_for(record)
          raise ArgumentError, "No Dash1 user ID for local_id #{record.local_id || 'nil'}, title '#{record.title}', tenant #{record.tenant_id}" unless dash1_user
          ensure_stash_user_id(dash1_user)
          dash1_user.uid
        end

        def stash_user_id_for(record)
          dash1_user = dash1_user_for(record)
          return nil unless dash1_user

          ensure_stash_user_id(dash1_user)
        end

        def dash1_user_for(record)
          dash1_user_id = dash1_user_id_for(record)
          return nil unless dash1_user_id

          users_by_id[dash1_user_id]
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
          return nil if value.casecmp('null').zero?
          return nil if value == ''
          int_value = value.to_i
          return int_value if int_value.to_s == value && int_value < 2000
          value
        end

        private

        def log
          Stash::Harvester.log
        end

        def stash_user_id_cache
          @stash_user_id_cache ||= {}
        end

        def ensure_stash_user_id(dash1_user)
          uid = dash1_user.uid
          stash_user_id_cache[uid] ||= begin
            ids = StashEngine::User.where(uid: uid).pluck(:id)
            if ids.size == 1
              log.info("Found existing Stash user #{ids[0]} for uid #{uid}")
              ids[0]
            elsif ids.empty?
              create_stash_user(dash1_user).id
            else
              raise IndexError, "Duplicate user IDs #{ids} for uid #{uid}"
            end
          end
        end

        def create_stash_user(dash1_user)
          stash_user = StashEngine::User.create(
            uid: dash1_user.uid,
            first_name: dash1_user.first_name,
            last_name: dash1_user.last_name,
            email: dash1_user.email,
            provider: dash1_user.provider,
            tenant_id: dash1_user.tenant_id,
            oauth_token: dash1_user.oauth_token
          )
          fields = dash1_user.to_h.map { |k, v| "#{k}: #{v || 'nil'}" }.join(', ')
          log.info("Created Stash user #{stash_user.id} for Dash 1 user: #{fields}")
          stash_user
        end

        def record_title(user_ids_by_title, record)
          user_id = record.user_id
          title = record.title
          user_ids_by_title[title] ||= []
          user_ids_by_title[title] << user_id unless user_ids_by_title[title].include?(user_id)
        end

        def record_local_id(user_ids_by_local_id, record)
          local_id = record.local_id
          return unless local_id
          user_id = record.user_id
          existing_user_id = user_ids_by_local_id[local_id]
          user_ids_by_local_id[local_id] = user_id unless existing_user_id
          return unless existing_user_id
          return if existing_user_id == user_id
          raise "Duplicate local_id '#{local_id}' for user IDs #{user_id || 'nil'}, #{existing_user_id}"
        end

        def dash1_user_id_for(record)
          local_id = record.local_id
          by_local_id = user_ids_by_local_id[local_id]
          return by_local_id if by_local_id

          title = record.title
          by_title = user_ids_by_title[title]
          return by_title[0] if by_title && by_title.size == 1

          if by_title
            warn "multiple users for title '#{title}': #{by_title}"
          else
            warn "no user for local_id #{local_id || 'nil'}, title '#{title}', tenant_id #{record.tenant_id}"
          end

          if record.tenant_id == 'lbnl'
            warn "returning test user cdluc3@gmail.com for #{local_id || 'nil'}, title '#{title}'"
            users_by_id[9999] ||= begin
              test_user = users_by_id[1003].dup
              test_user.tenant_id = 'lbnl'
              test_user.id = 9999
              test_user
            end
            9999
          end
        end

        def extract_dataset(r)
          OpenStruct.new(
            local_id: r.local_id,
            title: r.title,
            campus: r.campus
          )
        end

        def extract_user(r)
          OpenStruct.new(
            id: r.user_id.to_i,
            uid: r.uid,
            first_name: r.first_name,
            last_name: r.last_name,
            email: r.email,
            provider: r.provider,
            oauth_token: r.oauth_token,
            tenant_id: r.campus
          )
        end

      end
    end
  end
end
