require 'datacite/mapping'

module Datacite
  module Mapping
    class FundingReference
      def to_description
        grant_info = grant_number &&
                     if grant_number.include?('and')
                       " under grants #{grant_number}"
                     elsif grant_number.downcase.include?('grant') || grant_number.downcase.include?('agreement')
                       " under #{grant_number}"
                     else
                       " under grant #{grant_number}"
                     end

        article = 'the ' unless name.downcase.start_with?('the') || name.start_with?('Alexandr Kosenkov')

        desc_text = "Data were created with funding from #{article}#{name}#{grant_info}."
        Description.new(type: DescriptionType::OTHER, value: desc_text)
      end

      def grant_number
        award_number && award_number.value
      end
    end

    class Resource
      def funder_contribs
        @funder_contribs ||= contributors.select { |c| c.type == ContributorType::FUNDER }
      end

      def funding_descriptions
        descriptions.select { |desc| desc.type == DescriptionType::OTHER && !desc.value.start_with?('Lower and upper Providence Creek') }
      end

      def self.parse_mrt_datacite(mrt_datacite_xml, doi)
        # bad_contrib_regex = Regexp.new('<contributor contributorType="([^"]+)">\p{Space}*<contributor>([^<]+)</contributor>\p{Space}*</contributor>', Regexp::MULTILINE)
        # good_contrib_replacement = "<contributor contributorType=\"\\1\">\n<contributorName>\\2</contributorName>\n</contributor>"
        # datacite_xml = mrt_datacite_xml.gsub(bad_contrib_regex, good_contrib_replacement)
        datacite_xml = fix_special_cases(mrt_datacite_xml)

        resource = parse_xml(datacite_xml, mapping: :nonvalidating)
        resource.identifier = Datacite::Mapping::Identifier.new(value: doi)
        resource.fix_funding!
        resource
      end

      def fix_funding!
        funder_contribs.zip(funding_descriptions) do |funder_contrib, funding_desc|
          descriptions.delete(funding_desc)
          all_names, all_grants = names_and_grants(funder_contrib, funding_desc)
          all_names.zip(all_grants).each do |funder_name, grant_number|
            award_number = grant_number && grant_number != 'nil' && grant_number !~ /^\s*$/ ? grant_number : nil
            fref = FundingReference.new(name: funder_name, identifier: identifier_for(funder_contrib), award_number: award_number)
            funding_references << fref
            descriptions << fref.to_description
          end
        end
      end

      # <!-- ____________________________________________________________ -->
      # <!-- uci-ark+=b7280=d15k5m-mrt-datacite.xml -->
      # <fundingReference><funderName>National Institutes of Health and National Science Foundation</funderName><awardNumber>1R01GM108889-01 (NIH), CHE 1352608 and CHE-0840513 (NSF)</awardNumber></fundingReference>
      # <description descriptionType='Other' xml:lang='en'>Data were created with funding from the National Institutes of Health and National Science Foundation under grants 1R01GM108889-01 (NIH), CHE 1352608 and CHE-0840513 (NSF).</description>

      def self.fix_special_cases(datacite_xml)
        cases = {
          Regexp.new('<contributor contributorType="([^"]+)">\p{Space}*<contributor>([^<]+)</contributor>\p{Space}*</contributor>', Regexp::MULTILINE) =>
              "<contributor contributorType=\"\\1\">\n<contributorName>\\2</contributorName>\n</contributor>",
          'Affaits, National Institutes of Health,' => 'Affairs; National Institutes of Health;',
          'NIH RO1 HL31113, VA BX001970' => 'VA BX001970; NIH RO1 HL31113; nil',
          'Funding for the preparation of this data was supported by the Bill &amp; Melinda Gates Foundation. The original data collection was supported by grants from the MacArthur Foundation, National Institutes of Health, and the Bill &amp; Melinda Gates Foundation.' =>
                'Bill &amp; Melinda Gates Foundation; MacArthur Foundation; National Institutes of Health; Bill &amp; Melinda Gates Foundation',
          'Current dataset preparation: Bill and Melinda Gates Foundation (OPP1086183). Original data collection: MacArthur Foundation (05-84956-000-GSS), National Institutes of Health (R01HD053129) and Bill and Melinda Gates Foundation (48541).' =>
                'OPP1086183; 05-84956-000-GSS; R01HD053129; 48541',
          'National Institute of Health' => 'National Institutes of Health',
          'National Geographic Society and National Eye Institute, NIH, US.' =>
                'National Geographic Society; National Institutes of Health, National Eye Institute',
          'NGS W104-10 and NIH EY022087' => 'NGS W104-10; NIH EY022087',
          'National Institutes of Health and National Science Foundation' => 'National Institutes of Health; National Science Foundation',
          '1R01GM108889-01 (NIH), CHE 1352608 and CHE-0840513 (NSF)' => '1R01GM108889-01; CHE 1352608 and CHE-0840513',
          'National Science Foundation. Office' => 'National Science Foundation, Office',
          'National Science Foundation. Division' => 'National Science Foundation, Division',
          'National Institutes of Health. National' => 'National Institutes of Health, National',
          '. Select a sub-organization' => '',
          'US Bureau of Reclamation Cooperative Agreement' => 'Cooperative Agreement',
          '<description descriptionType="Other"/>' => '',
          '<description descriptionType="Other">0</description>' => ''
        }
        cases.each do |regex, replacement|
          datacite_xml = datacite_xml.gsub(regex, replacement)
        end
        datacite_xml
      end
      private_class_method(:fix_special_cases)

      private

      def names_and_grants(funder_contrib, funding_desc)
        funder_contrib_name = funder_contrib.name.strip
        funding_desc_value = funding_desc && funding_desc.value
        return [[funder_contrib_name], []] unless funding_desc_value

        grant_numbers = funding_desc_value.split(';').map do |s|
          s.strip.chomp(',')
        end
        funder_names = funder_contrib_name.split(';').map(&:strip)
        if grant_numbers.size == funder_names.size
          [funder_names, grant_numbers]
        else
          [[funder_contrib_name], [funding_desc_value]]
        end
      end

      def identifier_for(funder_contrib)
        funder_name_id = funder_contrib.identifier
        if funder_name_id
          funder_id_scheme = funder_name_id.scheme
          funder_id_type = FunderIdentifierType.find_by_value_str(funder_id_scheme) || FunderIdentifierType::OTHER
          FunderIdentifier.new(type: funder_id_type, value: funder_name_id.value)
        end
      end
    end
  end
end