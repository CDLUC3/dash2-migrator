require 'xml/mapping_extensions'
require 'datacite/mapping/empty_filtering_nodes'

module Eml
  module Mapping
    class Dataset
      include XML::MappingExtensions

      text_node :title, 'title'
    end

    class Creator
      object_node :individual_name, 'individualName', class: IndividualName
    end

    class IndividualName
      text_node :given_name, 'givenName'
      text_node :surname, 'surName'
    end

    class EmlTextNode < XML::Mapping::TextNode
      include EmptyNodeUtils

      NOT_PROVIDED = /No.*provided/

      def xml_to_obj(_obj, xml)
        super if (element = has_element?(xml)) && not_empty(element) && value_provided(element)
      end

      private

      def value_provided(element)
        text = element.text.strip
        return true unless NOT_PROVIDED.match(text)
        warn "Ignoring missing value #{element}"
      end

      def has_element?(xml) # rubocop:disable Style/PredicateName
        @path.first(xml)
      rescue XML::XXPathError
        false
      end
    end
  end
end
