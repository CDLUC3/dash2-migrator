require 'spec_helper'

module Dash2
  module Migrator
    module Importer
      describe FakeDOIMinter do
        it 'mints a DOI'
        it 'sets the DOI on the StashWrapper'
        it 'sets the DOI on the Datacite::Resource'
        it 'sets the DOI on the StashEngine::Resource'
        it 'updates the metadata for the fake DOI'
        it 'documents the migration in the StashWrapper'
        it 'documents the migration in the Datacite::Resource'
        it 'documents the migration as a StashDatacite::AlternateIdentifier'
        it 'skips previously migrated records'
      end
    end
  end
end
