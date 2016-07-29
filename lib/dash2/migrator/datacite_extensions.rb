require 'datacite/mapping'

module Datacite
  module Mapping

    class FundingReference
      def to_description
        desc_text = "Data were created with funding from the #{name} under grant #{award_number.value}."
        Description.new(type: DescriptionType::OTHER, value: desc_text)
      end
    end

    class Resource
      def self.parse_mrt_datacite(mrt_datacite_xml, doi)
        bad_contrib_regex = Regexp.new('<contributor contributorType="([^"]+)">\p{Space}*<contributor>([^<]+)</contributor>\p{Space}*</contributor>', Regexp::MULTILINE)
        good_contrib_replacement = "<contributor contributorType=\"\\1\">\n<contributorName>\\2</contributorName>\n</contributor>"
        datacite_xml = mrt_datacite_xml.gsub(bad_contrib_regex, good_contrib_replacement)

        resource = parse_xml(datacite_xml, mapping: :nonvalidating)
        resource.identifier = Datacite::Mapping::Identifier.new(value: doi)
        resource.fix_funding!
        resource
      end

      def fix_funding!
        funder_name = self.funder_name

        funding_desc = self.descriptions.find { |desc| desc.type == DescriptionType::OTHER }
        self.descriptions.delete(funding_desc)

        fref = FundingReference.new(name: funder_name, award_number: funding_desc.value)
        frefs = [fref]

        frefs.each do |f|
          self.descriptions << f.to_description
        end

        self.funding_references = frefs
      end
    end
  end
end
