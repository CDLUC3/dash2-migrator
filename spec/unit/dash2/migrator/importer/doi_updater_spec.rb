require 'spec_helper'

module Dash2
  module Migrator
    module Importer
      describe DOIUpdater do

        attr_reader :ezid_client
        attr_reader :tenant
        attr_reader :updater

        describe '#initialize' do

          describe ':ezid_client' do

            before(:each) do
              @tenant = instance_double(StashEngine::Tenant)
            end

            it 'accepts a StashEzid::Client' do
              @ezid_client = StashEzid::Client.new(
                shoulder: 'doi:10.5072/FK2',
                account: 'apitest',
                password: 'apitest',
                id_scheme: 'doi',
                owner: nil
              )
              expect(DOIUpdater.new(ezid_client: ezid_client, tenant: tenant).ezid_client).to be(ezid_client)
            end

            it 'rejects a nil ezid_client' do
              expect { DOIUpdater.new(ezid_client: nil, tenant: tenant) }.to raise_error(ArgumentError)
            end

            it 'rejects a missing ezid_client' do
              expect { DOIUpdater.new(tenant: tenant) }.to raise_error(ArgumentError)
            end

            it 'rejects an Ezid::Client' do
              @ezid_client = Ezid::Client.new(user: 'apitest', password: 'apitest')
              expect { DOIUpdater.new(ezid_client: ezid_client, tenant: tenant) }.to raise_error(ArgumentError)
            end

            it 'accepts a mock StashEzid::Client' do
              @ezid_client = instance_double(StashEzid::Client)
              expect(DOIUpdater.new(ezid_client: ezid_client, tenant: tenant).ezid_client).to be(ezid_client)
            end
          end

          describe ':tenant' do
            before(:each) do
              @ezid_client = instance_double(StashEzid::Client)
            end

            it 'accepts a StashEngine::Tenant' do
              @tenant = StashEngine::Tenant.new(YAML.load_file('config/tenants/example.yml')['test'])
              expect(DOIUpdater.new(ezid_client: ezid_client, tenant: tenant).tenant).to be(tenant)
            end

            it 'rejects a nil tenant' do
              expect { DOIUpdater.new(ezid_client: ezid_client, tenant: nil) }.to raise_error(ArgumentError)
            end

            it 'rejects a missing tenant' do
              expect { DOIUpdater.new(ezid_client: ezid_client) }.to raise_error(ArgumentError)
            end

            it 'rejects a hash' do
              expect { DOIUpdater.new(ezid_client: ezid_client, tenant: { tenant_id: 'ucop' }) }.to raise_error(ArgumentError)
            end

            it 'accepts a mock StashEngine::Tenant' do
              @tenant = instance_double(StashEngine::Tenant)
              expect(DOIUpdater.new(ezid_client: ezid_client, tenant: tenant).tenant).to be(tenant)
            end
          end

        end

        describe 'DOI mismatch' do

          before(:each) do
            @ezid_client = instance_double(StashEzid::Client)
            @tenant = instance_double(StashEngine::Tenant)
            @updater = DOIUpdater.new(ezid_client: ezid_client, tenant: tenant)
          end

          it 'fails if the input DOIs don\'t match' do
            dois = %w(10.123/456 10.456/789 10.789/123)
            dois.each do |sw_doi|
              dois.each do |dcs_doi|
                dois.each do |se_doi|
                  next if sw_doi == dcs_doi && dcs_doi == se_doi
                  stash_wrapper = instance_double(Stash::Wrapper::StashWrapper)
                  expect(stash_wrapper).to receive(:identifier) { Stash::Wrapper::Identifier.new(value: sw_doi, type: Stash::Wrapper::IdentifierType::DOI) }

                  dcs_resource = instance_double(Datacite::Mapping::Resource)
                  expect(dcs_resource).to receive(:identifier) { Datacite::Mapping::Identifier.new(value: dcs_doi) }

                  se_resource = instance_double(StashEngine::Resource)
                  expect(se_resource).to receive(:identifier) {
                    se_ident = double(StashEngine::Identifier)
                    expect(se_ident).to receive(:identifier) { se_doi }
                    se_ident
                  }
                  expect do
                    updater.update(
                      stash_wrapper: stash_wrapper,
                      se_resource: se_resource,
                      dcs_resource: dcs_resource
                    )
                  end.to raise_error(ArgumentError)
                end
              end
            end
          end

          describe '#{successful }update' do
            attr_reader :stash_wrapper
            attr_reader :dcs_resource
            attr_reader :se_resource
            attr_reader :sw_version
            attr_reader :doi_value

            before(:each) do
              @doi_value = '10.123/456'
              @sw_version = Stash::Wrapper::Version.new(number: 1, date: Date.today)

              @stash_wrapper = instance_double(Stash::Wrapper::StashWrapper)
              expect(stash_wrapper).to receive(:identifier) { Stash::Wrapper::Identifier.new(value: doi_value, type: Stash::Wrapper::IdentifierType::DOI) }
              allow(stash_wrapper).to receive(:version) { sw_version }

              @dcs_resource = instance_double(Datacite::Mapping::Resource)
              expect(dcs_resource).to receive(:identifier) { Datacite::Mapping::Identifier.new(value: doi_value) }
              expect(dcs_resource).to receive(:write_xml).with(mapping: :datacite_3).and_return('<resource/>')

              @se_resource = instance_double(StashEngine::Resource)
              expect(se_resource).to receive(:identifier) {
                se_ident = double(StashEngine::Identifier)
                expect(se_ident).to receive(:identifier) { doi_value }
                se_ident
              }

              expect(tenant).to receive(:landing_url).with("/stash/dataset/doi:#{doi_value}") do |path|
                "http://example.org#{path}"
              end

              allow(ezid_client).to receive(:update_metadata)
            end

            it 'updates the metadata' do
              expect(ezid_client).to receive(:update_metadata).with(
                "doi:#{doi_value}",
                '<resource/>',
                "http://example.org/stash/dataset/doi:#{doi_value}"
              )

              updater.update(
                stash_wrapper: stash_wrapper,
                se_resource: se_resource,
                dcs_resource: dcs_resource
              )
            end

            it 'documents the migration in the Stash::Wrapper::Version' do
              updater.update(stash_wrapper: stash_wrapper, se_resource: se_resource, dcs_resource: dcs_resource)
              expect(sw_version.note).to match(/Migrated at #{Time.now.year}/)
            end

            it 'forwards errors' do
              expect(ezid_client).to receive(:update_metadata).and_raise(ArgumentError)
              expect { updater.update(stash_wrapper: stash_wrapper, se_resource: se_resource, dcs_resource: dcs_resource) }.to raise_error(ArgumentError)
            end
          end
        end
      end
    end
  end
end
