require 'active_support'
require 'logger'

module Dash2
  module Migrator
    module Indexer
      Dir.glob(File.expand_path('../indexer/*.rb', __FILE__)).sort.each(&method(:require))

      class Indexer < Stash::Indexer::Indexer

        Importer = Dash2::Migrator::Importer::Importer

        attr_reader :db_config
        attr_reader :tenant_config

        def initialize(db_config:, tenant_config:)
          super(metadata_mapper: nil)
          @db_config = db_config
          @tenant_config = tenant_config
        end

        def demo_mode?
          !Migrator.production?
        end

        def index(harvested_records)
          ensure_db_connection!
          harvested_records.each do |hr|
            begin
              result = do_index(hr)
              yield result if block_given?
            rescue => e
              log_error(e)
              yield Stash::Indexer::IndexResult.failure(hr, [e]) if block_given?
            end
          end
        end

        def do_index(hr)
          # ark = hr.ark
          # tenant_id = hr.tenant_id
          # local_id = hr.local_id
          # title = hr.title
          #
          # title.gsub!(/\A[[:space:]]+/, '')
          # title.gsub!(/[[:space:]]+\z/, '')
          # title.gsub!(/[[:space:]]+/, ' ')
          #
          # info = "#{tenant_id}\t#{ark}\t#{local_id || 'nil'}\t\"#{title}\""
          # File.open('/tmp/titles.txt', 'a') { |f| f.puts(info) }
          #
          # puts info
          index_record(stash_wrapper: hr.as_wrapper, user_uid: hr.user_uid, ark: ark)
          Stash::Indexer::IndexResult.success(hr)
        end

        def ezid_config
          @ezid_config ||= tenant_config[:identifier_service]
        end

        def ezid_client
          @ezid_client ||= begin
            # TODO: eliminate these logging hijinks
            client = StashEzid::Client.new(ezid_config)
            inner_client = client.instance_variable_get(:@ezid_client)
            inner_client.instance_variable_set(:@logger, Migrator.log) if inner_client
            client
          end
        end

        def tenant
          @tenant ||= StashEngine::Tenant.new(tenant_config)
        end

        def sword_client
          @sword_client ||= Stash::Sword::Client.new(tenant.sword_params)
        end

        def importer
          @importer ||= Importer.new(ezid_client: ezid_client, sword_client: sword_client, tenant: tenant)
        end

        private

        def log_error(e)
          Migrator.log.error(e)
          (backtrace = e.backtrace) && Migrator.log.error(backtrace.join("\n"))
        end

        def index_record(stash_wrapper:, user_uid:, ark:)
          ident_value = (sw_ident = stash_wrapper.identifier) && sw_ident.value
          Migrator.log.info("Migrating #{ident_value || ark} for #{user_uid}")
          ActiveRecord::Base.transaction(requires_new: true) do
            importer.import(stash_wrapper: stash_wrapper, user_uid: user_uid, ark: ark)
          end
        end

        def ensure_db_connection!
          ActiveRecord::Base.connection
        rescue ActiveRecord::ConnectionNotEstablished
          ActiveRecord::Base.establish_connection(db_config)
        end
      end
    end
  end
end
