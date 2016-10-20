require 'spec_helper'

module Dash2
  module Migrator
    module Importer
      describe Importer do

        attr_reader :user_uid
        attr_reader :user_id

        before(:all) do
          @user_uid = 'lmuckenhaupt-ucop@ucop.edu'
          @user_id = 17
        end

        describe 'ARK-only wrapper' do
          it 'adds a "same as" alt. ident to the datacite XML'
          it 'mints a new DOI'
          it 'injects the new DOI into the datacite XML'
          it 'updates EZID with the new datacite XML'
        end

        describe 'wrapper with DOI' do
          describe 'existing resource w/same DOI' do
            it 'creates a database resource'
            describe 'with "migrated from" alt. ident' do
              it 'copies "migrated from" alt. ident to new resource'
              it 'copies "migrated from" alt. ident to datacite XML'
              it 'doesn\'t create duplicate alt. ident if already in new resource'
            end
            it 'copies SWORD update URI if present'
            it 'creates SWORD update URI from DOI if not present'
            it 'deletes the old resource'
            it 'updates EZID with new datacite XML and landing page'
            it 'updates the Stash wrapper with the latest Datacite XML'
            it 'submits a SWORD update'
          end
          describe 'existing resource migrated from original DOI' do
            it 'creates a database resource'
            it 'copies the DOI from the old resource to the new resource'
            it 'copies the DOI from the old resource to the Datacite XML'
            describe 'with "migrated from" alt. ident' do
              it 'copies "migrated from" alt. ident to new resource'
              it 'copies "migrated from" alt. ident to datacite XML'
              it 'doesn\'t create duplicate alt. ident if already in new resource'
            end
            it 'copies SWORD update URI if present'
            it 'creates SWORD update URI from DOI if not present'
            it 'deletes the old resource'
            it 'updates EZID with new datacite XML and landing page'
            it 'updates the Stash wrapper with the latest Datacite XML'
            it 'submits a SWORD update'
          end
          describe 'first migration for this DOI' do
            describe 'production' do
              it 'creates SWORD update URI from DOI'
              it 'updates EZID with new datacite XML and landing page'
              it 'submits a SWORD update'
            end
            describe 'dev/test' do
              it 'adds a "migrated from" alt. ident to the DB resource'
              it 'adds a "migrated from" alt. ident to the Datacite XML'
              it 'mints a new fake DOI targeting the Dash landing page'
              it 'updates the DB resource with the new DOI'
              it 'updates the Datacite XML with the new DOI'
              it 'updates EZID with new datacite XML and landing page'
              it 'updates the Stash wrapper with the latest Datacite XML'
              it 'submits a SWORD create'
            end
          end
        end
      end
    end
  end
end
