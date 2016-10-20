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

        attr_reader :new_doi_value
        attr_reader :final_doi_value
        attr_reader :final_ark

        attr_reader :final_datacite_3_xml
        attr_reader :final_datacite_4_xml

        attr_reader :stash_wrapper

        attr_reader :ezid_client
        attr_reader :deposit_receipt
        attr_reader :sword_client

        def new_doi
          "doi:#{new_doi_value}"
        end

        def final_doi
          "doi:#{final_doi_value}"
        end

        def final_update_uri
          update_uri_for(final_doi)
        end

        def final_download_uri
          download_uri_for(final_ark)
        end

        def download_uri_for(ark)
          raise 'No ARK provided' unless ark
          "http://repo.example.org/download/#{ERB::Util.url_encode(ark)}"
        end

        def update_uri_for(doi)
          raise 'No DOI provided' unless doi
          "http://sword.example.org/edit/#{ERB::Util.url_encode(doi)}"
        end

        # ----------------------------------------
        # Setup/Teardown

        before(:all) do
          @user_uid = 'lmuckenhaupt-ucop@ucop.edu'
          @user_id = 17
        end

        before(:each) do
          @ezid_client = instance_double(StashEzid::Client)
          @new_doi_value = (time = Time.now) && "10.5072/FK#{time.to_i}.#{time.nsec}"
          allow(ezid_client).to receive(:mint_id).and_return(new_doi)
          allow(ezid_client).to receive(:update_metadata)

          @deposit_receipt = instance_double(Stash::Sword::DepositReceipt)
          allow(deposit_receipt).to receive(:em_iri) { final_download_uri }
          allow(deposit_receipt).to receive(:edit_iri) { final_update_uri }

          @sword_client = instance_double(Stash::Sword::Client)
          allow(sword_client).to receive(:create).and_return(deposit_receipt)
        end

        after(:each) do
          # TODO: is this necessary?
          @new_doi_value = nil
          @final_doi_value = nil
          @final_ark = nil
        end

        # ----------------------------------------
        # Shared examples

        shared_examples 'mints a new DOI' do
          it 'mints a new DOI' do
            expect(ezid_client).to have_received(:mint_id)
          end
        end

        shared_examples 'updates EZID' do
          it 'updates EZID with new datacite XML and landing page' do
            expect(ezid_client).to have_recieved(:update_metadata).with(
              final_doi,
              final_datacite_3_xml,
              tenant.landing_url("/stash/dataset/#{final_doi}")
            )
          end
        end

        shared_examples 'updates wrapped Datacite' do
          it 'updates the Stash wrapper with the latest Datacite XML' do
            wrapped_resource = stash_wrapper.datacite_resource
            expect(wrapped_resource).to be_xml(final_datacite_4_xml)
          end
        end

        shared_examples 'submits SWORD create' do
          it 'submits a SWORD create' do
            expect(sword_client).to have_recieved(:create).with(hash_including(doi: final_doi))
          end
        end

        shared_examples 'submits SWORD update' do
          it 'submits a SWORD update' do
            expect(sword_client).to have_recieved(:update).with(hash_including(edit_iri: final_doi))
          end
        end

        shared_examples 'with "migrated from" alt. ident' do
          it 'copies "migrated from" alt. ident to new resource'
          it 'copies "migrated from" alt. ident to datacite XML'
          it 'doesn\'t create duplicate alt. ident if already in new resource'
        end

        # ----------------------------------------
        # Tests

        describe 'ARK-only wrapper' do
          before(:each) do
            @stash_wrapper = Stash::Wrapper::StashWrapper.parse_xml('spec/data/indexer/stash_wrapper_ark.xml')
          end

          it 'adds a "same as" alt. ident to the datacite XML'
          include_examples 'mints a new DOI'
          it 'injects the new DOI into the datacite XML'
          include_examples 'updates EZID'
        end

        describe 'wrapper with DOI' do
          before(:each) do
            @stash_wrapper = Stash::Wrapper::StashWrapper.parse_xml('spec/data/indexer/stash_wrapper_doi.xml')
          end

          describe 'existing resource w/same DOI' do
            it 'creates a database resource'
            include_examples 'with "migrated from" alt. ident'
            it 'copies SWORD update URI if present'
            it 'creates SWORD update URI from DOI if not present'
            it 'deletes the old resource'
            include_examples 'updates EZID'
            include_examples 'updates wrapped Datacite'
            include_examples 'submits SWORD update'
          end
          describe 'existing resource migrated from original DOI' do
            it 'creates a database resource'
            it 'copies the DOI from the old resource to the new resource'
            it 'copies the DOI from the old resource to the Datacite XML'
            include_examples 'with "migrated from" alt. ident'
            it 'copies SWORD update URI if present'
            it 'creates SWORD update URI from DOI if not present'
            it 'deletes the old resource'
            include_examples 'updates EZID'
            include_examples 'updates wrapped Datacite'
            include_examples 'submits SWORD update'
          end
          describe 'first migration for this DOI' do
            describe 'production' do
              it 'creates SWORD update URI from DOI'
              include_examples 'updates EZID'
              include_examples 'updates wrapped Datacite'
              include_examples 'submits SWORD update'
            end
            describe 'dev/test' do
              it 'adds a "migrated from" alt. ident to the DB resource'
              it 'adds a "migrated from" alt. ident to the Datacite XML'
              include_examples 'mints a new DOI'
              it 'updates the DB resource with the new DOI'
              it 'updates the Datacite XML with the new DOI'
              include_examples 'updates EZID'
              include_examples 'updates wrapped Datacite'
              include_examples 'submits SWORD create'
            end
          end
        end
      end
    end
  end
end
