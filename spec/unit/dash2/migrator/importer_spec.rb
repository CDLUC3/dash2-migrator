require 'spec_helper'
require 'erb'

module Dash2
  module Migrator
    module Importer

      describe Importer do

        # ----------------------------------------
        # Fixture

        attr_reader :user_uid
        attr_reader :user_id

        attr_reader :tenant

        attr_reader :wrapper_doi_value
        attr_reader :minted_doi_value
        attr_reader :expected_doi_value
        attr_reader :expected_ark

        attr_reader :stash_wrapper

        attr_reader :ezid_client
        attr_reader :deposit_receipt
        attr_reader :sword_client

        attr_reader :resource_builder
        attr_reader :new_resource
        attr_reader :new_resource_id

        attr_reader :old_resource_id

        def new_doi
          "doi:#{minted_doi_value}"
        end

        def expected_doi
          "doi:#{expected_doi_value}"
        end

        def expected_update_uri
          update_uri_for(expected_doi)
        end

        def expected_download_uri
          download_uri_for(expected_ark)
        end

        def download_uri_for(ark)
          raise 'No ARK provided' unless ark
          "http://repo.example.org/download/#{ERB::Util.url_encode(ark)}"
        end

        def update_uri_for(doi)
          raise 'No DOI provided' unless doi
          "http://sword.example.org/edit/#{ERB::Util.url_encode(doi)}"
        end

        def wrapped_datacite
          stash_wrapper.datacite_resource
        end

        # ----------------------------------------
        # Setup/Teardown

        before(:all) do
          @user_uid = 'lmuckenhaupt-ucop@ucop.edu'
          @user_id = 17
        end

        before(:each) do
          user = instance_double(StashEngine::User)
          allow(user).to receive(:id).and_return(user_id)
          allow(StashEngine::User).to receive(:find_by).with(uid: user_uid).and_return(user)

          @ezid_client = instance_double(StashEzid::Client)
          @minted_doi_value = (time = Time.now) && "10.5072/FK#{time.to_i}.#{time.nsec}"
          allow(ezid_client).to receive(:mint_id).and_return(new_doi)
          allow(ezid_client).to receive(:update_metadata)

          @deposit_receipt = instance_double(Stash::Sword::DepositReceipt)
          allow(deposit_receipt).to receive(:em_iri) { expected_download_uri }
          allow(deposit_receipt).to receive(:edit_iri) { expected_update_uri }

          @sword_client = instance_double(Stash::Sword::Client)
          allow(sword_client).to receive(:create).and_return(deposit_receipt)

          @resource_builder = instance_double(StashDatacite::ResourceBuilder)
          allow(StashDatacite::ResourceBuilder).to receive(:new).and_return(resource_builder)

          @new_resource_id = 53
          @new_resource = double(StashEngine::Resource)
          allow(new_resource).to receive(:id).and_return(new_resource_id)
          allow(resource_builder).to receive(:build).and_return(new_resource)
        end

        # ----------------------------------------
        # Shared examples

        shared_examples 'mints a new DOI' do
          it 'mints a new DOI' do
            expect(ezid_client).to have_received(:mint_id)
          end
        end

        shared_examples 'ensures Datacite XML has the correct DOI' do
          it 'sets the DOI in the Datacite XML' do
            identifier = wrapped_resource.identifier
            expect(identifier.type).to eq('DOI')
            expect(identifier.value).to eq(expected_doi_value)
          end
        end

        shared_examples 'updates EZID' do
          include_examples 'ensures Datacite XML has the correct DOI'
          it 'updates EZID with new datacite XML and landing page' do
            expected_datacite_3_xml = wrapped_resource.write_xml(mapping: :datacite_3)
            expect(ezid_client).to have_recieved(:update_metadata).with(
              expected_doi,
              expected_datacite_3_xml,
              tenant.landing_url("/stash/dataset/#{expected_doi}")
            )
          end
        end

        shared_examples 'submits SWORD create' do
          it 'submits a SWORD create' do
            expect(sword_client).to have_recieved(:create).with(hash_including(doi: expected_doi))
          end
        end

        shared_examples 'submits SWORD update' do
          it 'submits a SWORD update' do
            expect(sword_client).to have_recieved(:update).with(hash_including(edit_iri: expected_update_uri))
          end
        end

        shared_examples 'with "migrated from" alt. ident' do |options|
          let(:previously_migrated_from) { options[:previously_migrated_from] }

          before(:each) do
            previously_migrated_resource_id = 117
            @old_resource_id = previously_migrated_resource_id

            alt_ident = double(StashDatacite::AlternateIdentifier)
            allow(alt_ident).to receive(:alternate_identifier).and_return(previously_migrated_from)
            allow(alt_ident).to receive(:resource_id).and_return(previously_migrated_resource_id)
            allow(StashDatacite::AlternateIdentifier)
              .to receive(:find_by)
              .with(alternate_identifier: previously_migrated_from)
              .and_return(alt_ident)
          end

          it 'copies "migrated from" alt. ident to new resource'
          it 'copies "migrated from" alt. ident to datacite XML'
          it 'doesn\'t create duplicate alt. ident if already in new resource'
        end

        # ----------------------------------------
        # Tests

        describe 'ARK-only wrapper' do
          before(:each) do
            @stash_wrapper = Stash::Wrapper::StashWrapper.parse_xml('spec/data/indexer/stash_wrapper_ark.xml')
            @wrapper_doi_value = nil
            @expected_doi_value = minted_doi_value
          end

          it 'adds a "same as" alt. ident to the datacite XML'
          include_examples 'mints a new DOI'
          include_examples 'updates EZID'
        end

        describe 'wrapper with DOI' do
          before(:each) do
            @stash_wrapper = Stash::Wrapper::StashWrapper.parse_xml('spec/data/indexer/stash_wrapper_doi.xml')
            @wrapper_doi_value = '10.15146/R3RG6G'
          end

          describe 'existing resource w/same DOI' do
            before(:each) do
              @expected_doi_value = wrapper_doi_value
            end
            it 'creates a database resource'
            include_examples 'with "migrated from" alt. ident', previously_migrated_from: '10.123/previously-migrated-value'
            it 'copies SWORD update URI if present'
            it 'creates SWORD update URI from DOI if not present'
            it 'deletes the old resource'
            include_examples 'updates EZID'
            include_examples 'submits SWORD update'
          end

          describe 'existing resource migrated from original DOI' do
            before(:each) do
              @expected_doi_value = '10.123/previous-fake-doi'
            end
            it 'creates a database resource'
            it 'copies the DOI from the old resource to the new resource'
            it 'copies the DOI from the old resource to the Datacite XML'
            include_examples 'with "migrated from" alt. ident', previously_migrated_from: wrapper_doi_value
            it 'copies SWORD update URI if present'
            it 'creates SWORD update URI from DOI if not present'
            it 'deletes the old resource'
            include_examples 'updates EZID'
            include_examples 'submits SWORD update'
          end

          describe 'first migration for this DOI' do
            describe 'production' do
              before(:each) do
                @expected_doi_value = wrapper_doi_value
              end
              it 'creates SWORD update URI from DOI'
              include_examples 'updates EZID'
              include_examples 'submits SWORD update'
            end

            describe 'dev/test' do
              before(:each) do
                @expected_doi_value = minted_doi_value
              end
              it 'adds a "migrated from" alt. ident to the DB resource'
              it 'adds a "migrated from" alt. ident to the Datacite XML'
              include_examples 'mints a new DOI'
              it 'updates the DB resource with the new DOI'
              include_examples 'updates EZID'
              include_examples 'submits SWORD create'
            end
          end
        end
      end
    end
  end
end
