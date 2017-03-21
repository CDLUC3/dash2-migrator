require 'db_spec_helper'

module Dash2
  module Reversioning
    describe Updater do
      attr_reader :doi
      attr_reader :identifier
      attr_reader :resources
      attr_reader :versions

      before(:each) do
        @doi = '10.123/456'
        @identifier = StashEngine::Identifier.create(identifier: doi, identifier_type: 'DOI')

        res0 = StashEngine::Resource.create
        res0.ensure_identifier(doi)
        res0.current_state = :published
        res0.save!

        res1 = res0.amoeba_dup
        res1.current_state = :processing
        res1.save!

        res2 = res1.amoeba_dup
        res2.save!

        @resources = [res0, res1, res2]

        @versions = resources.map(&:stash_version)

        # TODO WTF?
        expect(versions.map(&:version)).to contain_exactly(1, 2, 3)
      end

      it 'updates the version' do

      end

    end
  end
end
