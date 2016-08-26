require 'stash/wrapper'
require 'datacite/mapping'

module Stash
  module Wrapper
    class StashWrapper
      def datacite_resource
        @datacite_resource ||= Datacite::Mapping::Resource.parse_xml(stash_descriptive[0])
      end

      def datacite_resource=(resource)
        stash_descriptive[0] = resource.save_to_xml
        @datacite_resource = nil
      end

      def stash_files
        return [] unless inventory
        inventory.files
      end

    end
  end
end
