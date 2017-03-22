require 'db_spec_helper'

module Dash2
  module Reversioning
    describe Updater do
      attr_reader :doi
      attr_reader :identifier
      attr_reader :resources

      before(:each) do
        @doi = '10.123/456'
        @identifier = StashEngine::Identifier.create(identifier: doi, identifier_type: 'DOI')

        res0 = StashEngine::Resource.create
        res0.ensure_identifier(doi)
        res0.current_state = :published
        res0.save!

        res1 = res0.amoeba_dup
        res1.save!
        res1.current_state = :processing

        res2 = res1.amoeba_dup
        res2.save!

        @resources = [res0, res1, res2]

        # just to be sure
        expect(versions.map(&:version)).to eq([1, 2, 3])
        expect(versions.map(&:merritt_version)).to eq([1, 2, 3])

        allow(Dash2::Reversioning).to receive(:dry_run?).and_return(false)
      end

      after(:each) do
        allow(Dash2::Reversioning).to receive(:dry_run?).and_call_original
      end

      def versions
        resources.map(&:stash_version)
      end

      it 'updates the version' do
        updater = Updater.new(doi: doi, last_merritt_version: 5, last_stash_version: 2)
        updater.update!
        resources.each(&:reload)

        expect(versions.map(&:version)).to eq([1, 2, 3])
        expect(versions.map(&:merritt_version)).to eq([4, 5, 6])
      end

      it 'leaves correct versions alone' do
        updater = Updater.new(doi: doi, last_merritt_version: 2, last_stash_version: 2)
        updater.update!
        resources.each(&:reload)

        expect(versions.map(&:version)).to eq([1, 2, 3])
        expect(versions.map(&:merritt_version)).to eq([1, 2, 3])
      end

      it 'ignores versions that already have the correct difference' do
        v0 = versions[0]
        v0.merritt_version = 4
        v0.save!
        expect(versions.map(&:merritt_version)).to eq([4, 2, 3]) # just to be sure

        updater = Updater.new(doi: doi, last_merritt_version: 5, last_stash_version: 2)
        updater.update!
        resources.each(&:reload)

        expect(versions.map(&:version)).to eq([1, 2, 3])
        expect(versions.map(&:merritt_version)).to eq([4, 5, 6])
      end

      describe 'dry run' do
        before(:each) do
          allow(Dash2::Reversioning).to receive(:dry_run?).and_return(true)
        end

        it 'leaves the DB alone' do
          updater = Updater.new(doi: doi, last_merritt_version: 5, last_stash_version: 2)
          updater.update!
          resources.each(&:reload)

          expect(versions.map(&:version)).to eq([1, 2, 3])
          expect(versions.map(&:merritt_version)).to eq([1, 2, 3])
        end
      end

    end
  end
end
