require 'db_spec_helper'

module Dash2
  module Migrator
    module Importer
      describe Importer do

        attr_reader :user
        attr_reader :user_uid

        attr_reader :sw_ark_xml
        attr_reader :sw_doi_xml
        attr_reader :stash_wrapper

        attr_reader :tenant

        attr_reader :ezid_client
        attr_reader :minted_doi
        attr_reader :ezid_resource

        attr_reader :sword_client

        attr_reader :importer

        def user_id
          user.id
        end

        def dash_landing_uri(doi)
          tenant.landing_url("/stash/dataset/#{doi}")
        end

        before(:all) do
          @user_uid = 'lmuckenhaupt-ucop@ucop.edu'
          @user = StashEngine::User.create(
            uid: user_uid,
            first_name: 'Lisa',
            last_name: 'Muckenhaupt',
            email: 'lmuckenhaupt@ucop.edu',
            provider: 'developer',
            tenant_id: 'ucop'
          )

          @sw_ark_xml = File.read('spec/data/indexer/stash_wrapper_ark.xml').freeze
          @sw_doi_xml = File.read('spec/data/indexer/stash_wrapper_doi.xml').freeze
        end

        before(:each) do
          allow_any_instance_of(Dash2::Migrator::Harvester::MerrittAtomHarvestedRecord).to receive(:user_uid) { user_uid }

          @ezid_client = instance_double(StashEzid::Client)
          allow(@ezid_client).to receive(:mint_id) { @minted_doi = (time = Time.now) && "doi:10.5072/FK#{time.to_i}.#{time.nsec}" }

          @sword_client = instance_double(Stash::Sword::Client)

          @tenant = StashEngine::Tenant.new(YAML.load_file('config/tenants/example.yml')['test'])

          @importer = Importer.new(
            tenant: tenant,
            ezid_client: ezid_client,
            sword_client: sword_client
          )
        end

        # def repo_landing_page(ark)
        #   "http://repo.example.org/landing/#{ERB::Util.url_encode(ark)}"
        # end
        #
        # def repo_download_page(ark)
        #   "http://repo.example.org/download/#{ERB::Util.url_encode(ark)}"
        # end

        describe 'ARK-only wrapper' do

          before(:each) do
            @stash_wrapper = Stash::Wrapper::StashWrapper.parse_xml(sw_ark_xml)
            importer.import(stash_wrapper: stash_wrapper, user_uid: user_uid)
          end

          it 'doesn\'t create a new resource' do
            expect(StashEngine::Resource.exists?).to be_falsey
          end

          it 'mints a new DOI' do
            expect(ezid_client).to have_received(:mint_id)
          end
        end

        describe 'wrapper with DOI' do
          attr_reader :wrapper_doi_value
          attr_reader :new_resource

          def new_resource_id
            new_resource.id
          end

          before(:each) do
            @stash_wrapper = Stash::Wrapper::StashWrapper.parse_xml(sw_doi_xml)
            @wrapper_doi_value = '10.15146/R3RG6G'
          end

          describe 'initial test migration' do
            before(:each) do
              expect(@ezid_client).to receive(:update_metadata) do |ident, xml_str, target|
                expect(ident).to eq(minted_doi)
                expect(target).to eq(dash_landing_uri(minted_doi))
                @ezid_resource = Datacite::Mapping::Resource.parse_xml(xml_str)
              end

              @new_resource = importer.import(stash_wrapper: stash_wrapper, user_uid: user_uid)
              expect(new_resource).to be_a(StashEngine::Resource)
              expect(StashEngine::Resource.count).to eq(1)
            end

            it 'mints a new DOI' do
              expect(ezid_client).to have_received(:mint_id)
              ident_value = (ident = new_resource.identifier) && ident.identifier
              expect(ident_value).not_to be_nil
              expect("doi:#{ident_value}").to eq(minted_doi)
            end

            it 'adds a "migrated from" alternate identifier to the resource' do
              alt_ident = StashDatacite::AlternateIdentifier.find(resource_id: new_resource_id, alternate_identifier_type: 'migrated from')
              expect(alt_ident).not_to be_nil
              expect(alt_ident.alternate_identifier).to eq("doi:#{wrapper_doi_value}")
            end

            describe 'EZID update' do
              it 'injects the newly minted DOI into the Datacite XML' do
                ident_value = (ident = ezid_resource.identifier) && ident.value
                expect(ident_value).to eq(minted_doi)
              end
              it 'adds a "migrated from" alternate identifier to the Datacite XML' do
                alt_ident = ezid_resource.alternate_identifiers.find { |ident| ident.type = 'migrated from' }
                expect(alt_ident).not_to be_nil
                expect(alt_ident.value).to eq(minted_doi)
              end
            end
          end

          # describe 'initial production migration' do
          #   before(:each) do
          #     allow(Migrator).to receive(:production?).and_return(true)
          #     importer.import(stash_wrapper: stash_wrapper, user_uid: user_uid)
          #   end
          #
          #   it 'creates a new resource' do
          #     expect(StashEngine::Resource.count).to eq(1)
          #   end
          # end

        end

        # describe 'wrapper with DOI' do
        #   describe 'existing resource w/same DOI' do
        #
        #     before(:each) do
        #       existing_ident = StashEngine::Identifier.create(identifier: wrapper_doi_value, identifier_type: 'DOI')
        #       @existing_resource = StashEngine::Resource.create(
        #         user_id: user_id,
        #         identifier_id: existing_ident.id
        #       )
        #     end
        #
        #     it 'creates a database resource'
        #     describe 'with "migrated from" alt. ident' do
        #       it 'copies "migrated from" alt. ident to new resource'
        #       it 'copies "migrated from" alt. ident to datacite XML'
        #       it 'doesn\'t create duplicate alt. ident if already in new resource'
        #     end
        #     it 'copies SWORD update URI if present'
        #     it 'creates SWORD update URI from DOI if not present'
        #     it 'deletes the old resource'
        #     it 'updates EZID with new datacite XML and landing page'
        #     it 'updates the Stash wrapper with the latest Datacite XML'
        #     it 'submits a SWORD update'
        #   end
        #   describe 'existing resource migrated from original DOI' do
        #     attr_reader :original_doi_value
        #     attr_reader :existing_migrated_from
        #
        #     before(:each) do
        #       @original_doi_value = "#{wrapper_doi_value}-original"
        #       @existing_resource = StashEngine::Resource.create(
        #         user_id: user_id
        #       )
        #       existing_ident = StashEngine::Identifier.create(identifier: original_doi_value, identifier_type: 'DOI')
        #     end
        #
        #     it 'creates a database resource'
        #     it 'copies the DOI from the old resource to the new resource'
        #     it 'copies the DOI from the old resource to the Datacite XML'
        #     describe 'with "migrated from" alt. ident' do
        #       it 'copies "migrated from" alt. ident to new resource'
        #       it 'copies "migrated from" alt. ident to datacite XML'
        #       it 'doesn\'t create duplicate alt. ident if already in new resource'
        #     end
        #     it 'copies SWORD update URI if present'
        #     it 'creates SWORD update URI from DOI if not present'
        #     it 'deletes the old resource'
        #     it 'updates EZID with new datacite XML and landing page'
        #     it 'updates the Stash wrapper with the latest Datacite XML'
        #     it 'submits a SWORD update'
        #   end
        #   describe 'first migration for this DOI' do
        #     describe 'production' do
        #       it 'creates SWORD update URI from DOI'
        #       it 'updates EZID with new datacite XML and landing page'
        #       it 'submits a SWORD update'
        #     end
        #     describe 'dev/test' do
        #       it 'adds a "migrated from" alt. ident to the DB resource'
        #       it 'adds a "migrated from" alt. ident to the Datacite XML'
        #       it 'mints a new fake DOI targeting the Dash landing page'
        #       it 'updates the DB resource with the new DOI'
        #       it 'updates the Datacite XML with the new DOI'
        #       it 'updates EZID with new datacite XML and landing page'
        #       it 'updates the Stash wrapper with the latest Datacite XML'
        #       it 'submits a SWORD create'
        #     end
        #   end
        # end
      end

    end
  end
end
