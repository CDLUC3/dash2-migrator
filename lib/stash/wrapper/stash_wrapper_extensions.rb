require 'stash/wrapper'
require 'datacite/mapping'

module Stash
  module Wrapper
    class StashWrapper
      def datacite_resource
        Datacite::Mapping::Resource.parse_xml(stash_descriptive[0])
      end

      def datacite_resource=(resource)
        stash_descriptive[0] = resource.save_to_xml
      end
    end
  end
end
