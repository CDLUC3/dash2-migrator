require 'stash/wrapper'

module Dash2
  module Migrator
    module Harvester
      class StashWrapperBuilder

        attr_reader :mrt_mom

        def initialize(mrt_mom:)
          @mrt_mom = mrt_mom
        end

        def build
          Stash::Wrapper::StashWrapper.new(
            identifier: Stash::Wrapper::Identifier.new(type: sw_ident_type, value: sw_ident_value),
            version: Stash::Wrapper::Version.new(number: 1, date: date),
            embargo: Stash::Wrapper::Embargo.new(type: Stash::Wrapper::EmbargoType::NONE, period: Stash::Wrapper::EmbargoType::NONE.value, start_date: date_published, end_date: date_published),
            license: stash_license,
            inventory: Stash::Wrapper::Inventory.new(files: stash_files),
            descriptive_elements: [datacite_xml]
          )
        end
      end
    end
  end
end
