require 'datacite/mapping'

module Datacite
  module Mapping

    class Rights
      # TODO: get real URL
      UCSF_DUA = Rights.new(
          uri: URI('https://datashare.ucsf.edu/xtf/search?smode=dataUseAgreementUCSF'),
          value: 'UCSF Datashare Data Use Agreement'
      ),
      # TODO: get real URL
      UCSF_FEB_13 = Rights.new(
          uri:  URI('https://merritt.cdlib.org/d/ark%3A%2Fb7272%2Fq6bg2kwf/6/producer%2FDUA_formal_BMJopen_female%20condomt.docx'),
          value: 'custom Data Use Agreement'
      )
    end

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
        contributors.select { |c| c.type == ContributorType::FUNDER }
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
        resource.convert_funding!
        resource
      end

      # Converts deprecated funder contributors to FundingReferences
      def convert_funding!
        funder_contribs.zip(funding_descriptions) do |funder_contrib, funding_desc|
          contributors.delete(funder_contrib)
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
          '<description descriptionType="Other">0</description>' => '',
          'rightsURI="http:' => 'rightsURI="https:',
          'https://creativecommons.org/about/cc0' => Rights::CC_ZERO.uri.to_s,
          'These data are covered by a Creative Commons CC0 license.' => Rights::CC_ZERO.value,
          'Creative Commons Public Domain Dedication (CC0)' => Rights::CC_ZERO.value,
          'Creative Commons Attribution 4.0 License' => Rights::CC_BY.value,
          'Creative Commons Attribution 4.0 International (CC-BY 4.0)' => Rights::CC_BY.value,
          '<rights>RatSCIA materials are free. In order to download the RatSCIA materials, please provide name, affiliation and email address when prompted. Information is gathered for tracking/funding purposes only.</rights>' => '',
          '<rights>Terms of Use for these data' => '<rights rightsURI="DUA_formal_BMJopen_female%20condomt.docx">Terms of Use for these data'
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
