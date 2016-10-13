require 'datacite/mapping'

module Datacite
  module Mapping
    class Description
      def value=(v)
        new_value = v && v.strip
        raise ArgumentError, "Invalid description value #{v.nil? ? 'nil' : "'#{v}'"}" unless new_value && !new_value.empty?
        @value = new_value.gsub(/-[ \n]+/, '')
      end
    end
  end
end
