require 'datacite/mapping'

module Datacite
  module Mapping

    class FundingReference
      def to_description
        grant_number = award_number && award_number.value
        grant_info = " under grant #{grant_number}" if grant_number

        desc_text = "Data were created with funding from #{name}#{grant_info}."
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
        funder_contrib = self.funder_contrib
        return unless funder_contrib

        funder_name = funder_contrib.name
        fref = FundingReference.new(name: funder_name)

        funding_desc = self.descriptions.find { |desc| desc.type == DescriptionType::OTHER && !desc.value.start_with?('Lower and upper Providence Creek') }
        if funding_desc
          self.descriptions.delete(funding_desc)
          fref.award_number = funding_desc.value
        end

        funder_name_id = funder_contrib.identifier
        if funder_name_id
          funder_id_scheme = funder_name_id.scheme
          funder_id_type = FunderIdentifierType.find_by_value_str(funder_id_scheme) || FunderIdentifierType::OTHER
          funder_id = FunderIdentifier.new(type: funder_id_type, value: funder_name_id.value)
          fref.identifier = funder_id
        end

        frefs = [fref]
        frefs.each do |f|
          self.descriptions << f.to_description
        end

        self.funding_references = frefs
      end
    end
  end
end
