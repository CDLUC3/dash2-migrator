require 'active_support'
require 'logger'

module Dash2
  module Migrator
    module Indexer
      Dir.glob(File.expand_path('../indexer/*.rb', __FILE__)).sort.each(&method(:require))

      class Indexer < Stash::Indexer::Indexer

        attr_reader :tenant_config

        def initialize(tenant_config:)
          super(metadata_mapper: nil)
          @tenant_config = tenant_config
          @mint_dois = mint_dois
          @production = Migrator.production?
        end

        def demo_mode?
          !@production
        end

        def index(harvested_records)
          harvested_records.each { |hr| index_record(hr.as_wrapper, hr.user_uid) }
        end

        def log
          Stash::Harvester.log
        end

        def ezid_config
          @ezid_config ||= tenant_config[:identifier_service]
        end

        def ezid_client
          @ezid_client ||= StashEzid::Client.new(ezid_config)
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
