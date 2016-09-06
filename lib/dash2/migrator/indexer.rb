require 'active_support'
require 'logger'

module Dash2
  module Migrator
    module Indexer
      Dir.glob(File.expand_path('../indexer/*.rb', __FILE__)).sort.each(&method(:require))

      class Indexer < Stash::Indexer::Indexer

        DOIUpdater = Dash2::Migrator::Importer::DOIUpdater
        SwordPackager = Dash2::Migrator::Importer::SwordPackager
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
          count = 0
          harvested_records.each do |hr|
            begin
              index_record(hr.as_wrapper, hr.user_uid)
              count += 1
              yield Stash::Indexer::IndexResult.success(hr) if block_given?
            rescue => e
              Migrator.log.error(e)
              (backtrace = e.backtrace) && Migrator.log.error(backtrace.join("\n"))
              yield Stash::Indexer::IndexResult.failure(hr, [e]) if block_given?
            end
          end
          Migrator.log.info("Migration complete; migrated #{count} records")
        end

        def ezid_config
          @ezid_config ||= tenant_config[:identifier_service]
        end

        def ezid_client
          @ezid_client ||= begin
                             # TODO: eliminate these logging hijinks
            client = StashEzid::Client.new(ezid_config)
            inner_client = client.instance_variable_get(:@ezid_client)
            inner_client.instance_variable_set(:@logger, Migrator.log)
            client
          end
        end

        def tenant
          @tenant ||= StashEngine::Tenant.new(tenant_config)
        end

        def doi_updater
          @doi_updater ||= DOIUpdater.new(ezid_client: ezid_client, tenant: tenant, mint_dois: demo_mode?)
        end

        def sword_client
          @sword_client ||= Stash::Sword::Client.new(tenant.sword_params)
        end

        def sword_packager
          @sword_packager ||= SwordPackager.new(sword_client: sword_client, create_placeholder_files: demo_mode?)
        end

        def importer
          @importer ||= Importer.new(doi_updater: doi_updater, sword_packager: sword_packager, tenant: tenant)
        end

        private

        def index_record(stash_wrapper, user_uid)
          ident_value = (sw_ident = stash_wrapper.identifier) && sw_ident.value
          Migrator.log.info("Migrating #{ident_value} for #{user_uid}")
          ActiveRecord::Base.transaction(requires_new: true) do
            importer.import(stash_wrapper: stash_wrapper, user_uid: user_uid)
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
