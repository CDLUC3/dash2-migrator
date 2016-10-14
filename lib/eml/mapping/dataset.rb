require 'xml/mapping_extensions'
require 'eml/mapping/eml_text_node'

module Eml
  module Mapping
    class Dataset
      include XML::MappingExtensions

      root_element_name 'eml'

      eml_text_node :title, 'title'
      object_node :creator, 'creator'
      eml_text_node :organization_name, 'organization_name'
    end

    class Creator
      object_node :individual_name, 'individualName', class: IndividualName
    end

    class IndividualName
      eml_text_node :given_name, 'givenName'
      eml_text_node :surname, 'surName'
    end

    class Address
      eml_text_node :delivery_point, 'deliveryPoint'
    end

  end
end
