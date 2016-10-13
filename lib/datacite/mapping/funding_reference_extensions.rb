require 'datacite/mapping'

module Datacite
  module Mapping
    class FundingReference
      def to_description
        article = name.downcase.start_with?('the') || name.start_with?('Alexandr Kosenkov') ? '' : 'the '
        desc_text = "Data were created with funding from #{article}#{name}#{grant_info}."
        Description.new(type: DescriptionType::OTHER, value: desc_text)
      end

      def grant_number
        award_number && award_number.value
      end

      def grant_info
        grant_number &&
          if grant_number.include?('and')
            " under grants #{grant_number}"
          elsif grant_number.downcase.include?('grant') || grant_number.downcase.include?('agreement')
            " under #{grant_number}"
          else
            " under grant #{grant_number}"
          end
      end
    end
  end
end
