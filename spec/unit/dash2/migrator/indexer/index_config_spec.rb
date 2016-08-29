require 'spec_helper'

module Dash2
  module Migrator
    module Indexer
      describe IndexConfig do

        attr_reader :db_yml
        attr_reader :tenant_yml
        attr_reader :config

        before(:each) do
          @db_yml = 'spec/data/indexer/database.yml'
          @tenant_yml = 'config/tenants/example.yml'
          @config = IndexConfig.new(db_config_path: db_yml, tenant_path: tenant_yml)
        end

        describe '#description' do
          it 'includes the tenant path' do
            expect(config.description).to include(tenant_yml)
          end

          it 'includes the database config path' do
            expect(config.description).to include(db_yml)
          end
          it 'identifies the production environment' do
            allow(Migrator).to receive(:production?).and_return(true)
            config = IndexConfig.new(db_config_path: db_yml, tenant_path: tenant_yml)
            expect(config.description).to include('production')
          end
        end

        describe '#db_config_path' do
          it 'returns the DB config path' do
            expect(config.db_config_path).to eq(File.absolute_path(db_yml))
          end
        end

        describe '#tenant_config' do
          it 'parses the tenant config for the environment as a symbol-keyed hash' do
            expected = {
              enabled: true,
              repository: {
                type: 'merritt',
                domain: 'merritt-dev.example.org',
                endpoint: 'http://sword-dev.example.org:39001/mrtsword/collection/test',
                username: 'test',
                password: 'test'
              },
              contact_email: ['contact1@example.edu', 'contact2@example.edu'],
              abbreviation: 'DataONE',
              short_name: 'DataONE',
              long_name: 'DataONE',
              full_domain: 'example-dev.example.org',
              domain_regex: 'example-dev.example.org$',
              tenant_id: 'dataone',
              identifier_service: {
                shoulder: 'doi:10.5072/FK2',
                account: 'test',
                password: 'test',
                id_scheme: 'doi',
                owner: nil
              },
              authentication: {
                strategy: 'google'
              },
              default_license: 'cc0',
              dash_logo_after_tenant: false
            }

            tenant_config = config.tenant_config
            expect(tenant_config).to eq(expected)
          end
        end

        describe '#create_indexer' do
          it 'creates an indexer' do
            indexer = config.create_indexer
            expect(indexer).to be_an(Indexer)
            expect(indexer.tenant_config).to eq(config.tenant_config)
          end
        end
      end
    end
  end
end
