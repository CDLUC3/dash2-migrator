require 'db_spec_helper'

module Dash2
  module Migrator
    module Importer

      describe Importer do

        attr_reader :user
        attr_reader :user_uid
        attr_reader :user_provider

        attr_reader :sw_ark_xml
        attr_reader :sw_doi_xml
        attr_reader :stash_wrapper
        attr_reader :ark
        attr_reader :doi_ark
        attr_reader :ark_ark

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

        def merritt_download_uri(ark)
          "http://merritt-dev.cdlib.org/d/#{ERB::Util.url_encode(ark)}"
        end

        def sword_update_uri(doi)
          "http://sword-aws-dev.cdlib.org:39001/mrtsword/edit/dash_cdl/#{ERB::Util.url_encode(doi)}"
        end

        def new_fake_doi
          (time = Time.now) && "doi:10.5072/FK#{time.to_i}.#{time.nsec}"
        end

        def value_of(doi)
          doi.match(Datacite::Mapping::DOI_PATTERN)[0]
        end

        def minted_doi_value
          value_of(minted_doi)
        end

        before(:all) do
          @user_uid = 'lmuckenhaupt-ucop@ucop.edu'

          @sw_ark_xml = File.read('spec/data/indexer/stash_wrapper_ark.xml').freeze
          @ark_ark = 'ark:/90135/q1f769jn'
          @sw_doi_xml = File.read('spec/data/indexer/stash_wrapper_doi.xml').freeze
          @doi_ark = 'ark:/c5146/r3rg6g'
        end

        before(:each) do
          allow_any_instance_of(Dash2::Migrator::Harvester::MerrittAtomHarvestedRecord).to receive(:user_uid) { user_uid }

          @ezid_client = instance_double(StashEzid::Client)
          allow(@ezid_client).to receive(:mint_id) { @minted_doi = new_fake_doi }

          @sword_client = instance_double(Stash::Sword::Client)
          allow(sword_client).to receive(:collection_uri).and_return('http://sword-aws-dev.cdlib.org:39001/mrtsword/collection/dash_cdl')
          allow(sword_client).to receive(:create) do |params|
            doi = params[:doi]

            edit_iri = Stash::Sword::Link.new
            edit_iri.rel = 'edit'
            edit_iri.href = sword_update_uri(doi)

            em_iri = Stash::Sword::Link.new
            em_iri.rel = 'edit-media'
            em_iri.href = merritt_download_uri(ark)

            receipt = Stash::Sword::DepositReceipt.new
            receipt.links = [edit_iri, em_iri]
            receipt
          end
          allow(sword_client).to receive(:update).and_return(200)

          @tenant = StashEngine::Tenant.new(YAML.load_file('config/tenants/example.yml')['test'])

          @user_provider = instance_double(Dash2::Migrator::Harvester::UserProvider)
          allow(user_provider).to receive(:ensure_uid!).and_return(user_uid)

          @importer = Importer.new(
            tenant: tenant,
            ezid_client: ezid_client,
            sword_client: sword_client,
            user_provider: user_provider
          )

          @user = StashEngine::User.create(
            uid: user_uid,
            first_name: 'Lisa',
            last_name: 'Muckenhaupt',
            email: 'lmuckenhaupt@ucop.edu',
            provider: 'developer',
            tenant_id: 'ucop'
          )
        end

        describe '#edit_uri_for' do
          it 'constructs a Merritt edit URI' do
            doi = 'doi:10.5072/FK2DF6R618'
            expected_uri = 'http://sword-aws-dev.cdlib.org:39001/mrtsword/edit/dash_cdl/doi%3A10.5072%2FFK2DF6R618'
            expect(importer.edit_uri_for(doi)).to eq(expected_uri)
          end
        end

        describe 'ARK-only wrapper' do

          attr_reader :new_resource

          def new_resource_id
            new_resource.id
          end

          before(:each) do
            @stash_wrapper = Stash::Wrapper::StashWrapper.parse_xml(sw_ark_xml)
            @ark = @ark_ark
          end

          describe 'production' do
            before(:each) do
              allow(Migrator).to receive(:production?).and_return(true)
              @new_resource = importer.import(stash_wrapper: stash_wrapper, user_uid: user_uid, ark: ark)
            end

            it 'mints a new DOI' do
              expect(ezid_client).to have_received(:mint_id)
            end

            it 'doesn\'t create a new resource' do
              expect(new_resource).not_to be_a(StashEngine::Resource)
              expect(StashEngine::Resource.exists?).to be_falsey
            end
          end

          describe 'test' do
            # TODO: shared with "initial test migration"
            before(:each) do
              expect(Migrator.production?).to eq(false)
              expect(@ezid_client).to receive(:update_metadata) do |ident, xml_str, target|
                expect(ident).to eq(minted_doi)
                expect(target).to eq(dash_landing_uri(minted_doi))
                @ezid_resource = Datacite::Mapping::Resource.parse_xml(xml_str)
              end

              @new_resource = importer.import(stash_wrapper: stash_wrapper, user_uid: user_uid, ark: ark)
              expect(new_resource).to be_a(StashEngine::Resource)
              expect(StashEngine::Resource.count).to eq(1)
            end

            it 'sets the user ID' do
              expect(new_resource.user_id).to eq(user_id)
            end

            it 'mints a new DOI' do
              expect(ezid_client).to have_received(:mint_id)
              ident_value = (ident = new_resource.identifier) && ident.identifier
              expect(ident_value).not_to be_nil
              expect(ident_value).to eq(minted_doi_value)
              expect(ident.identifier_type).to eq('DOI')
            end

            it 'adds a "migrated from" alternate identifier to the resource' do
              alt_ident = StashDatacite::AlternateIdentifier.find_by(resource_id: new_resource_id, alternate_identifier_type: 'migrated from')
              expect(alt_ident).not_to be_nil
              expect(alt_ident.alternate_identifier).to eq(ark)
            end

            describe 'EZID update' do
              it 'injects the newly minted DOI into the Datacite XML' do
                ident_value = (ident = ezid_resource.identifier) && ident.value
                expect(ident_value).to eq(minted_doi_value)
                expect(ident.identifier_type).to eq('DOI')
              end
              it 'adds a "migrated from" alternate identifier to the Datacite XML' do
                alt_ident = ezid_resource.alternate_identifiers.find { |ident| ident.type = 'migrated from' }
                expect(alt_ident).not_to be_nil
                expect(alt_ident.value).to eq(ark)
              end
            end

            it 'submits a SWORD create' do
              expect(sword_client).to have_received(:create).with(hash_including(doi: minted_doi))
              expect(new_resource.download_uri).to eq('http://merritt-dev.cdlib.org/d/ark%3A%2F90135%2Fq1f769jn')
              expect(new_resource.update_uri).to eq(sword_update_uri(minted_doi))
            end
          end

        end

        describe 'wrapper with DOI' do
          attr_reader :wrapper_doi_value
          attr_reader :new_resource

          def new_resource_id
            new_resource.id
          end

          def wrapper_doi
            "doi:#{wrapper_doi_value}"
          end

          before(:each) do
            @stash_wrapper = Stash::Wrapper::StashWrapper.parse_xml(sw_doi_xml)
            @wrapper_doi_value = '10.15146/R3RG6G'
            @ark = doi_ark
          end

          describe 'initial test migration' do
            before(:each) do
              expect(Migrator.production?).to eq(false)
              expect(@ezid_client).to receive(:update_metadata) do |ident, xml_str, target|
                expect(ident).to eq(minted_doi)
                expect(target).to eq(dash_landing_uri(minted_doi))
                @ezid_resource = Datacite::Mapping::Resource.parse_xml(xml_str)
              end

              @new_resource = importer.import(stash_wrapper: stash_wrapper, user_uid: user_uid, ark: ark)
              expect(new_resource).to be_a(StashEngine::Resource)
              expect(StashEngine::Resource.count).to eq(1)
            end

            it 'sets the user ID' do
              expect(new_resource.user_id).to eq(user_id)
            end

            it 'mints a new DOI' do
              expect(ezid_client).to have_received(:mint_id)
              ident_value = (ident = new_resource.identifier) && ident.identifier
              expect(ident_value).not_to be_nil
              expect(ident_value).to eq(minted_doi_value)
              expect(ident.identifier_type).to eq('DOI')
            end

            it 'adds a "migrated from" alternate identifier to the resource' do
              alt_ident = StashDatacite::AlternateIdentifier.find_by(resource_id: new_resource_id, alternate_identifier_type: 'migrated from')
              expect(alt_ident).not_to be_nil
              expect(alt_ident.alternate_identifier).to eq(wrapper_doi)
            end

            describe 'EZID update' do
              it 'injects the newly minted DOI into the Datacite XML' do
                ident_value = (ident = ezid_resource.identifier) && ident.value
                expect(ident_value).to eq(minted_doi_value)
                expect(ident.identifier_type).to eq('DOI')
              end
              it 'adds a "migrated from" alternate identifier to the Datacite XML' do
                alt_ident = ezid_resource.alternate_identifiers.find { |ident| ident.type = 'migrated from' }
                expect(alt_ident).not_to be_nil
                expect(alt_ident.value).to eq(wrapper_doi)
              end
            end

            it 'submits a SWORD create' do
              expect(sword_client).to have_received(:create).with(hash_including(doi: minted_doi))
              expect(new_resource.download_uri).to eq('http://merritt-dev.cdlib.org/d/ark%3A%2Fc5146%2Fr3rg6g')
              expect(new_resource.update_uri).to eq(sword_update_uri(minted_doi))
            end
          end

          describe 'initial production migration' do
            before(:each) do
              allow(Migrator).to receive(:production?).and_return(true)
              expect(@ezid_client).to receive(:update_metadata) do |ident, xml_str, target|
                expect(ident).to eq(wrapper_doi)
                expect(target).to eq(dash_landing_uri(wrapper_doi))
                @ezid_resource = Datacite::Mapping::Resource.parse_xml(xml_str)
              end

              @new_resource = importer.import(stash_wrapper: stash_wrapper, user_uid: user_uid, ark: ark)
              expect(new_resource).to be_a(StashEngine::Resource)
              expect(StashEngine::Resource.count).to eq(1)
            end

            it 'sets the user ID' do
              expect(new_resource.user_id).to eq(user_id)
            end

            it "doesn't mint a new DOI" do
              expect(ezid_client).not_to have_received(:mint_id)
              ident_value = (ident = new_resource.identifier) && ident.identifier
              expect(ident_value).not_to be_nil
              expect(ident_value).to eq(wrapper_doi_value)
              expect(ident.identifier_type).to eq('DOI')
            end

            it "doesn't add a 'migrated from' alternate identifier to the resource" do
              alt_ident = StashDatacite::AlternateIdentifier.find_by(resource_id: new_resource_id, alternate_identifier_type: 'migrated from')
              expect(alt_ident).to be_nil
            end

            describe 'EZID update' do
              it 'preserves the wrapper DOI' do
                ident_value = (ident = ezid_resource.identifier) && ident.value
                expect(ident_value).to eq(wrapper_doi_value)
                expect(ident.identifier_type).to eq('DOI')
              end
              it 'doesn\'t add a "migrated from" alternate identifier' do
                alt_ident = ezid_resource.alternate_identifiers.find { |ident| ident.type = 'migrated from' }
                expect(alt_ident).to be_nil
              end
            end

            it 'sets the SWORD update and download URIs' do
              expect(new_resource.update_uri).to eq(sword_update_uri(wrapper_doi))
              expect(new_resource.download_uri).to eq('https://merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr3rg6g')
            end

            it 'submits a SWORD update' do
              expect(sword_client).to have_received(:update).with(hash_including(edit_iri: sword_update_uri(wrapper_doi)))
            end

          end

          describe 'test re-migration' do

            attr_reader :existing_resource_id
            attr_reader :existing_fake_doi

            attr_reader :different_user

            def different_user_id
              different_user.id
            end

            def existing_fake_doi_value
              value_of(existing_fake_doi)
            end

            before(:each) do
              expect(Migrator.production?).to eq(false)
              @existing_fake_doi = new_fake_doi

              @different_user = StashEngine::User.create(
                uid: 'simon-ucop@ucop.edu',
                first_name: 'Simon',
                last_name: 'Bertucci',
                email: 'simon@ucop.edu',
                provider: 'developer',
                tenant_id: 'ucop'
              )

              existing_ident = StashEngine::Identifier.create(
                identifier: existing_fake_doi_value,
                identifier_type: 'DOI'
              )
              existing_resource = StashEngine::Resource.create(
                user_id: different_user_id,
                identifier_id: existing_ident.id,
                update_uri: sword_update_uri(existing_fake_doi)
              )
              @existing_resource_id = existing_resource.id

              StashDatacite::AlternateIdentifier.create(
                resource_id: existing_resource_id,
                alternate_identifier_type: 'migrated from',
                alternate_identifier: wrapper_doi
              )

              expect(ezid_client).not_to receive(:mint_id)
              expect(@ezid_client).to receive(:update_metadata) do |ident, xml_str, target|
                expect(ident).to eq(existing_fake_doi)
                expect(target).to eq(dash_landing_uri(existing_fake_doi))
                @ezid_resource = Datacite::Mapping::Resource.parse_xml(xml_str)
              end

              @new_resource = importer.import(stash_wrapper: stash_wrapper, user_uid: user_uid, ark: ark)
            end

            it 'creates a new resource' do
              expect(new_resource).to be_a(StashEngine::Resource)
              expect(new_resource_id).not_to eq(existing_resource_id)
            end

            it 'transfers the DOI from the existing resource' do
              ident_value = (ident = new_resource.identifier) && ident.identifier
              expect(ident_value).not_to be_nil
              expect(ident_value).to eq(existing_fake_doi_value)
              expect(ident.identifier_type).to eq('DOI')
            end

            it 'copies the alternate identifier from the existing resource' do
              alt_ident = StashDatacite::AlternateIdentifier.find_by(resource_id: new_resource_id, alternate_identifier_type: 'migrated from')
              expect(alt_ident).not_to be_nil
              expect(alt_ident.alternate_identifier).to eq(wrapper_doi)
            end

            it 'copies the SWORD update URI' do
              update_uri = new_resource.update_uri
              expect(update_uri).to eq(sword_update_uri(existing_fake_doi))
            end

            it 'copies the user ID' do
              expect(new_resource.user_id).to eq(different_user_id)
            end

            it 'deletes the old resource' do
              expect(StashEngine::Resource.exists?(existing_resource_id)).to be(false)
              expect(StashEngine::Resource.count).to eq(1)
              expect(StashDatacite::AlternateIdentifier.find_by(resource_id: existing_resource_id)).to be_nil
            end

            describe 'EZID update' do
              it 'injects the existing DOI into the Datacite XML' do
                ident_value = (ident = ezid_resource.identifier) && ident.value
                expect(ident_value).to eq(existing_fake_doi_value)
                expect(ident.identifier_type).to eq('DOI')
              end
              it 'adds a "migrated from" alternate identifier to the Datacite XML' do
                alt_ident = ezid_resource.alternate_identifiers.find { |ident| ident.type = 'migrated from' }
                expect(alt_ident).not_to be_nil
                expect(alt_ident.value).to eq(wrapper_doi)
              end
            end
          end
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
