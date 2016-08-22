require 'spec_helper'

module Dash2
  module Migrator
    module Importer
      describe DOIUpdater do

        describe '#initialize' do

          it 'accepts a StashEzid::Client' do
            client = StashEzid::Client.new(
                shoulder: 'doi:10.5072/FK2',
                account: 'apitest',
                password: 'apitest',
                id_scheme: 'doi',
                owner: nil
            )
            expect(DOIUpdater.new(ezid_client: client).ezid_client).to be(client)
          end

          it 'rejects a nil client' do
            expect { DOIUpdater.new(ezid_client: nil) }.to raise_error(ArgumentError)
          end

          it 'rejects a missing client' do
            expect { DOIUpdater.new }.to raise_error(ArgumentError)
          end

          it 'rejects an Ezid::Client' do
            client = Ezid::Client.new(user: 'apitest', password: 'apitest')
            expect { DOIUpdater.new(ezid_client: client) }.to raise_error(ArgumentError)
          end

          it 'accepts a mock StashEzid::Client' do
            client = instance_double(StashEzid::Client)
            expect(DOIUpdater.new(ezid_client: client).ezid_client).to be(client)
          end
        end

        describe '#update_doi' do
          it 'fails if the input DOIs don\'t match' do
            updater = DOIUpdater.new(ezid_client: instance_double(StashEzid::Client))

            dois = %w(10.123/456 10.456/789 10.789/123)
            dois.each do |sw_doi|
              dois.each do |dcs_doi|
                dois.each do |se_doi|
                  unless sw_doi == dcs_doi && dcs_doi == se_doi
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
                    expect {
                      updater.update(
                          stash_wrapper: stash_wrapper,
                          se_resource: se_resource,
                          dcs_resource: dcs_resource
                      )
                    }.to raise_error(ArgumentError)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
