require 'spec_helper'

module Dash2
  module Migrator
    module Importer
      describe "#{DOIUpdater} (minting)" do
        attr_reader :old_doi_value
        attr_reader :new_doi_value

        attr_reader :ezid_client
        attr_reader :tenant
        attr_reader :updater

        attr_reader :sw_ident
        attr_reader :sw_version

        attr_reader :dcs_ident
        attr_reader :dcs_alt_idents

        attr_reader :se_ident
        attr_reader :se_ident_id

        attr_reader :se_resource_id

        attr_reader :stash_wrapper
        attr_reader :dcs_resource
        attr_reader :se_resource

        attr_reader :sd_alt_ident

        def old_doi
          "doi:#{old_doi_value}"
        end

        def new_doi
          "doi:#{new_doi_value}"
        end

        describe '#initialize' do
          it 'raises an exception if invoked in production' do
            expect(ENV['STASH_ENV']).to eq('test')
            @ezid_client = instance_double(StashEzid::Client)
            @tenant = instance_double(StashEngine::Tenant)
            begin
              ENV['STASH_ENV'] = 'production'
              expect { DOIUpdater.new(mint_dois: true, ezid_client: ezid_client, tenant: tenant) }.to raise_error(ArgumentError)
            ensure
              ENV['STASH_ENV'] = 'test'
            end
          end
        end

        describe '#update' do
          before(:each) do
            @old_doi_value = '10.123/456'
            @new_doi_value = '10.321/abc'

            @ezid_client = instance_double(StashEzid::Client)
            allow(@ezid_client).to receive(:mint_id) { "doi:#{new_doi_value}" }
            allow(ezid_client).to receive(:update_metadata)

            @tenant = instance_double(StashEngine::Tenant)
            allow(tenant).to receive(:landing_url).with("/stash/dataset/doi:#{new_doi_value}") do |path|
              "http://example.org#{path}"
            end

            @updater = DOIUpdater.new(mint_dois: true, ezid_client: ezid_client, tenant: tenant)

            @sw_ident = Stash::Wrapper::Identifier.new(value: old_doi_value, type: Stash::Wrapper::IdentifierType::DOI)
            @stash_wrapper = instance_double(Stash::Wrapper::StashWrapper)
            allow(stash_wrapper).to receive(:identifier) { sw_ident }

            @sw_version = Stash::Wrapper::Version.new(number: 1, date: Date.today)
            allow(stash_wrapper).to receive(:version) { sw_version }

            @dcs_ident = Datacite::Mapping::Identifier.new(value: old_doi_value)
            @dcs_alt_idents = []
            @dcs_resource = instance_double(Datacite::Mapping::Resource)
            allow(dcs_resource).to receive(:identifier) { dcs_ident }
            allow(dcs_resource).to receive(:alternate_identifiers) { dcs_alt_idents }
            allow(dcs_resource).to receive(:write_xml) { '<resource/>' }

            @se_ident_id = 23
            @se_ident = double(StashEngine::Identifier)
            allow(se_ident).to receive(:id).and_return(se_ident_id)
            allow(StashEngine::Identifier).to receive(:create).with(
              identifier: new_doi_value,
              identifier_type: 'DOI'
            ).and_return(se_ident)

            @se_resource_id = 17
            @se_resource = double(StashEngine::Resource)
            allow(se_resource).to receive(:identifier) { nil }
            allow(se_resource).to receive(:id) { @se_resource_id }
            allow(se_resource).to receive(:identifier_id=).with(se_ident_id)
            allow(se_resource).to receive(:save)

            @sd_alt_ident = double(StashDatacite::AlternateIdentifier)
            allow(StashDatacite::AlternateIdentifier).to receive(:create) { sd_alt_ident }
            allow(sd_alt_ident).to receive(:save)
            allow(StashDatacite::AlternateIdentifier).to receive(:where)
          end

          it 'mints a DOI' do
            expect(@ezid_client).to receive(:mint_id) { "doi:#{new_doi_value}" }
            updater.update(
              stash_wrapper: stash_wrapper,
              se_resource: se_resource,
              dcs_resource: dcs_resource
            )
          end

          describe 'DOI injection' do
            it 'sets the DOI on the StashWrapper' do
              updater.update(stash_wrapper: stash_wrapper, se_resource: se_resource, dcs_resource: dcs_resource)
              expect(sw_ident.value).to eq(new_doi_value)
            end

            it 'sets the DOI on the Datacite::Resource' do
              updater.update(stash_wrapper: stash_wrapper, se_resource: se_resource, dcs_resource: dcs_resource)
              expect(dcs_ident.value).to eq(new_doi_value)
            end

            it 'sets the DOI on the StashEngine::Resource' do
              expect(se_resource).to receive(:identifier_id=).with(se_ident_id)
              expect(se_resource).to receive(:save)
              updater.update(stash_wrapper: stash_wrapper, se_resource: se_resource, dcs_resource: dcs_resource)
            end
          end

          it 'updates the metadata for the fake DOI' do
            expect(ezid_client).to receive(:update_metadata).with(
              "doi:#{new_doi_value}",
              '<resource/>',
              "http://example.org/stash/dataset/doi:#{new_doi_value}"
            )
            updater.update(stash_wrapper: stash_wrapper, se_resource: se_resource, dcs_resource: dcs_resource)
          end

          describe 'migration documentation' do
            it 'documents the migration in the Stash::Wrapper::Version' do
              updater.update(stash_wrapper: stash_wrapper, se_resource: se_resource, dcs_resource: dcs_resource)
              expect(sw_version.note).to match(/Migrated from #{old_doi} to #{new_doi}/)
            end

            it 'documents the migration in the Datacite::Resource' do
              updater.update(stash_wrapper: stash_wrapper, se_resource: se_resource, dcs_resource: dcs_resource)

              expect(dcs_alt_idents.size).to eq(1)
              dcs_alt_ident = dcs_alt_idents[0]
              expect(dcs_alt_ident.value).to eq(old_doi)
              expect(dcs_alt_ident.type).to eq('migrated from')
            end

            it 'documents the migration as a StashDatacite::AlternateIdentifier' do
              expect(StashDatacite::AlternateIdentifier).to receive(:create).with(
                resource_id: se_resource_id,
                alternate_identifier_type: 'migrated from',
                alternate_identifier: old_doi
              ) { sd_alt_ident }
              expect(sd_alt_ident).to receive(:save)

              updater.update(stash_wrapper: stash_wrapper, se_resource: se_resource, dcs_resource: dcs_resource)
            end

            it 'raises an error for previously migrated records' do
              expect(StashDatacite::AlternateIdentifier).to receive(:where).with(alternate_identifier: old_doi) { sd_alt_ident }
              expect { updater.update(stash_wrapper: stash_wrapper, se_resource: se_resource, dcs_resource: dcs_resource) }.to raise_error(ArgumentError)
            end
          end
        end
      end
    end
  end
end
