require 'datacite/mapping'

module Datacite
  module Mapping
    class Identifier
      def value=(v)
        new_value = v && v.strip
        warn 'Identifier should have a non-nil value' unless new_value
        warn "Identifier value #{"'#{new_value}'" || 'nil'} is not a valid DOI" unless new_value.match(DOI_PATTERN)
        @value = new_value
      end

      def identifier_type=(v)
        warn "Identifier type '#{v}' should be 'DOI'" unless DOI == v
        @identifier_type = v
      end
    end
  end
end

module Datacite
  module Mapping
    class NameIdentifier
      def value=(v)
        new_value = v && v.strip
        warn 'Identifier should have a non-nil value' unless new_value && !new_value.empty?
        @value = new_value
      end
    end
  end
end
