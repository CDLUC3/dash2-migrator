require 'stash/wrapper'
require 'datacite/mapping'

module Stash
  module Wrapper
    class StashWrapper
      attr_reader :datacite_resource

      def id_value
        identifier && identifier.value
      end

      def datacite_resource=(resource)
        raise ArgumentError, "Not a resource: #{resource}" unless resource.nil? || resource.is_a?(Datacite::Mapping::Resource) # || resource.to_s =~ /InstanceDouble\(#{Datacite::Mapping::Resource}\)/
        @datacite_resource = resource
      end

      def stash_descriptive
        return [] unless datacite_resource
        [datacite_resource.save_to_xml]
      end

      def stash_descriptive=(value)
        raise ArgumentError, "Not an array: #{value}" unless value.nil? || (value.respond_to?(:empty?) && value.respond_to?(:[]))
        @datacite_resource.nil? unless value && !value.empty?
        @datacite_resource = Datacite::Mapping::Resource.parse_xml(value[0])
      end

      def stash_files
        return [] unless inventory
        inventory.files
      end

    end

    class Identifier
      # TODO: consdier pushing this to stash-wrapper
      def value=(v)
        new_value = v && v.strip
        new_value.upcase if new_value && type == IdentifierType::DOI
        @value = new_value
      end
    end
  end
end
