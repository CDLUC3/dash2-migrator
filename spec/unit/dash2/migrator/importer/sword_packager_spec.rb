require 'spec_helper'

module Dash2
  module Migrator
    module Importer
      describe SwordPackager do

        describe '#initialize' do
          it 'requires a client' do
            expect { SwordPackager.new }.to raise_error(ArgumentError)
          end

          it 'rejects a nil client' do
            expect { SwordPackager.new(sword_client: nil) }.to raise_error(ArgumentError)
          end

          it 'accepts a Stash::Sword::Client' do
            client = Stash::Sword::Client.new(
              collection_uri: 'http://sword-aws-dev.cdlib.org:39001/mrtsword/collection/demo_open_context',
              username: 'dataone_dash_submitter',
              password: 'w2NnJ8qj'
            )
            expect(SwordPackager.new(sword_client: client).sword_client).to be(client)
          end

          it 'accepts a mock Stash::Sword::Client' do
            client = instance_double(Stash::Sword::Client)
            expect(SwordPackager.new(sword_client: client).sword_client).to be(client)
          end

          it 'disallows placeholder files in production' do
            expect(ENV['STASH_ENV']).to eq('test')
            client = instance_double(Stash::Sword::Client)
            begin
              ENV['STASH_ENV'] = 'production'
              expect { SwordPackager.new(sword_client: client, create_placeholder_files: true) }.to raise_error(ArgumentError)
            ensure
              ENV['STASH_ENV'] = 'test'
            end
          end
        end

        describe '#submit' do

          attr_reader :sword_client
          attr_reader :doi_value

          attr_reader :stash_wrapper
          attr_reader :dcs_resource
          attr_reader :se_resource
          attr_reader :tenant

          attr_reader :packager
          attr_reader :package_builder

          attr_reader :expected_zipfile

          before(:each) do
            @sword_client = instance_double(Stash::Sword::Client)
            allow(sword_client).to receive(:collection_uri).and_return('http://example.org/sword')

            @doi_value = '10.123/456'

            @stash_wrapper = instance_double(Stash::Wrapper::StashWrapper)
            @dcs_resource = instance_double(Datacite::Mapping::Resource)
            @se_resource = double(StashEngine::Resource)
            allow(se_resource).to receive(:identifier) {
              se_ident = double(StashEngine::Identifier)
              allow(se_ident).to receive(:identifier) { doi_value }
              se_ident
            }
            allow(se_resource).to receive(:id) { 17 }

            @tenant = instance_double(StashEngine::Tenant)

            @packager = SwordPackager.new(sword_client: sword_client)
            @package_builder = instance_double(ZipPackageBuilder)
          end

          describe '#create' do

            before(:each) do
              allow(se_resource).to receive(:update_uri) { nil }

              expect(ZipPackageBuilder).to receive(:new).with(
                stash_wrapper: stash_wrapper,
                dcs_resource: dcs_resource,
                se_resource: se_resource,
                tenant: tenant,
                create_placeholder_files: false
              ) { package_builder }

              @expected_zipfile = 'archive.zip'
              allow(package_builder).to receive(:make_package) { expected_zipfile }
            end

            it 'submits a zip package as a create' do
              em_iri = 'http://example.org/em_iri'
              edit_iri = 'http://example.org/edit_iri'
              receipt = instance_double(Stash::Sword::DepositReceipt)
              allow(receipt).to receive(:em_iri) { em_iri }
              allow(receipt).to receive(:edit_iri) { edit_iri }
              expect(sword_client).to receive(:create).with(doi: "doi:#{doi_value}", zipfile: expected_zipfile) { receipt }
              allow(sword_client).to receive(:collection_uri).and_return('http://example.org/sword')

              expect(se_resource).to receive(:download_uri=).with(em_iri)
              expect(se_resource).to receive(:update_uri=).with(edit_iri)

              expect(se_resource).to receive(:current_state=).with('published')
              expect(se_resource).to receive(:update_version).with(expected_zipfile)
              expect(se_resource).to receive(:save)

              zipfile = packager.submit(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource, tenant: tenant)
              expect(zipfile).to eq(expected_zipfile)
            end

            it 'retries' do
              em_iri = 'http://example.org/em_iri'
              edit_iri = 'http://example.org/edit_iri'
              receipt = instance_double(Stash::Sword::DepositReceipt)
              allow(receipt).to receive(:em_iri) { em_iri }
              allow(receipt).to receive(:edit_iri) { edit_iri }

              retries = Dash2::Migrator::Importer::SwordSubmitTask::RETRIES
              allow(sword_client).to receive(:create).with(doi: "doi:#{doi_value}", zipfile: expected_zipfile) do
                raise RestClient::Exceptions::ReadTimeout unless (retries -= 1).zero?
                receipt
              end

              expect(se_resource).to receive(:download_uri=).with(em_iri)
              expect(se_resource).to receive(:update_uri=).with(edit_iri)

              expect(se_resource).to receive(:current_state=).with('published')
              expect(se_resource).to receive(:update_version).with(expected_zipfile)
              expect(se_resource).to receive(:save)

              zipfile = packager.submit(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource, tenant: tenant)
              expect(zipfile).to eq(expected_zipfile)
              expect(retries).to eq(0)
            end

            it 'eventually raises RestClient::Exceptions::ReadTimeout' do
              allow(sword_client).to receive(:create).with(doi: "doi:#{doi_value}", zipfile: expected_zipfile) do
                raise RestClient::Exceptions::ReadTimeout
              end

              expect do
                packager.submit(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource, tenant: tenant)
              end.to raise_error(RestClient::Exceptions::ReadTimeout, /#{expected_zipfile}.*#{doi_value}/)
            end
          end

          describe '#update' do

            attr_reader :edit_iri

            before(:each) do
              @edit_iri = 'http://example.org/edit_iri'
              allow(se_resource).to receive(:update_uri) { edit_iri }

              expect(ZipPackageBuilder).to receive(:new).with(
                stash_wrapper: stash_wrapper,
                dcs_resource: dcs_resource,
                se_resource: se_resource,
                tenant: tenant,
                create_placeholder_files: false
              ) { package_builder }

              @expected_zipfile = 'archive.zip'
              expect(package_builder).to receive(:make_package) { expected_zipfile }
            end

            it 'submits a zip package as an update' do

              expect(sword_client).to receive(:update).with(edit_iri: edit_iri, zipfile: expected_zipfile) { '200' }

              expect(se_resource).to receive(:current_state=).with('published')
              expect(se_resource).to receive(:update_version).with(expected_zipfile)
              expect(se_resource).to receive(:save)

              zipfile = packager.submit(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource, tenant: tenant)
              expect(zipfile).to eq(expected_zipfile)
            end

            it 'retries' do
              retries = Dash2::Migrator::Importer::SwordSubmitTask::RETRIES
              allow(sword_client).to receive(:update).with(edit_iri: edit_iri, zipfile: expected_zipfile) do
                raise RestClient::Exceptions::ReadTimeout unless (retries -= 1).zero?
                '200'
              end

              expect(se_resource).to receive(:current_state=).with('published')
              expect(se_resource).to receive(:update_version).with(expected_zipfile)
              expect(se_resource).to receive(:save)

              zipfile = packager.submit(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource, tenant: tenant)
              expect(zipfile).to eq(expected_zipfile)
              expect(retries).to eq(0)
            end

            it 'eventually raises RestClient::Exceptions::ReadTimeout' do
              allow(sword_client).to receive(:update).with(edit_iri: edit_iri, zipfile: expected_zipfile) do
                raise RestClient::Exceptions::ReadTimeout
              end

              expect do
                packager.submit(stash_wrapper: stash_wrapper, dcs_resource: dcs_resource, se_resource: se_resource, tenant: tenant)
              end.to raise_error(RestClient::Exceptions::ReadTimeout, /#{expected_zipfile}.*#{edit_iri}/)
            end

          end
        end

      end
    end
  end
end
