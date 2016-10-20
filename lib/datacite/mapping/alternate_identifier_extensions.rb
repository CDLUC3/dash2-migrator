require 'datacite/mapping'

module Datacite
  module Mapping
    class AlternateIdentifier
      # TODO: push this back into datacite-mapping

      def value=(v)
        new_value = v && v.strip
        raise ArgumentError, 'Alternate identifier must have a non-nil value' unless new_value
        @value = new_value
      end
    end
  end
end
