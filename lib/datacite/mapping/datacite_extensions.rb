require 'datacite/mapping'
require 'datacite/mapping/alternate_identifier_extensions'
require 'datacite/mapping/description_extensions'
require 'datacite/mapping/funding_reference_extensions'
require 'datacite/mapping/identifier_extensions'
require 'datacite/mapping/resource_extensions'
require 'datacite/mapping/rights_extensions'

module Datacite
  module Mapping

    class Resource
      DOI_PATTERN = %r{10\.[^/\s]+/[^;\s]+$}
      ARK_PATTERN = %r{ark:/[a-z0-9]+/[a-z0-9]+}

      SPECIAL_CASES = {
        %r{<(identifier|subject|description)[^>]+/>} => '', # remove empty tags
        %r{<(identifier|subject|description)[^>]+>\s*</\1>} => '', # remove empty tag pairs
        %r{(<date[^>]*>)(\d{4})-(\d{4})(</date>)} => '\\1\\2/\\3\\4', # fix date ranges
        %r{(<contributor[^>/]+>\s*)<contributor>([^<]+)</contributor>(\s*</contributor>)} => '\\1<contributorName>\\2</contributorName>\\3', # fix broken contributors
        'rightsURI="doi:' => 'rightsURI="https://dx.doi.org/',
        'Affaits, National Institutes of Health,' => 'Affairs; National Institutes of Health;',
        'NIH RO1 HL31113, VA BX001970' => 'VA BX001970; NIH RO1 HL31113; nil', # the string 'nil' is special in add_funding_reference()
        'Funding for the preparation of this data was supported by the Bill &amp; Melinda Gates Foundation. The original data collection was supported by grants from the MacArthur Foundation, National Institutes of Health, and the Bill &amp; Melinda Gates Foundation.' =>
          'Bill &amp; Melinda Gates Foundation; MacArthur Foundation; National Institutes of Health; Bill &amp; Melinda Gates Foundation',
        'Current dataset preparation: Bill and Melinda Gates Foundation (OPP1086183). Original data collection: MacArthur Foundation (05-84956-000-GSS), National Institutes of Health (R01HD053129) and Bill and Melinda Gates Foundation (48541).' => 'OPP1086183; 05-84956-000-GSS; R01HD053129; 48541',
        'National Institute of Health' => 'National Institutes of Health',
        'National Geographic Society and National Eye Institute, NIH, US.' => 'National Geographic Society; National Institutes of Health, National Eye Institute',
        'NGS W104-10 and NIH EY022087' => 'NGS W104-10; NIH EY022087',
        'National Institutes of Health and National Science Foundation' => 'National Institutes of Health; National Science Foundation',
        '1R01GM108889-01 (NIH), CHE 1352608 and CHE-0840513 (NSF)' => '1R01GM108889-01; CHE 1352608 and CHE-0840513',
        'National Science Foundation. Office' => 'National Science Foundation, Office',
        'National Science Foundation. Division' => 'National Science Foundation, Division',
        'National Institutes of Health. National' => 'National Institutes of Health, National',
        '. Select a sub-organization' => '',
        'US Bureau of Reclamation Cooperative Agreement' => 'Cooperative Agreement',
        '<description descriptionType="Other">0</description>' => '',
        'rightsURI="http:' => 'rightsURI="https:',
        'https://creativecommons.org/about/cc0' => Rights::CC_ZERO.uri.to_s,
        'These data are covered by a Creative Commons CC0 license.' => Rights::CC_ZERO.value,
        'Creative Commons Public Domain Dedication (CC0)' => Rights::CC_ZERO.value,
        'Creative Commons Attribution 4.0 License' => Rights::CC_BY.value,
        'Creative Commons Attribution 4.0 International (CC-BY 4.0)' => Rights::CC_BY.value,
        '<geoLocationPlace>false</geoLocationPlace>' => '',

        %r{(<geoLocationPlace>\s*Orange County \(Calif\.\)\s*</geoLocationPlace>)} => "\\1\n      <geoLocationBox>33.947514 -118.1259 33.333992 -117.412987</geoLocationBox>\n      <geoLocationPoint>33.676911 -117.776166</geoLocationPoint>",
        %r{(<geoLocationPlace>\s*Providence Creek \(Lower, Upper and P301\)\s*</geoLocationPlace>)} => "\\1\n      <geoLocationPoint>37.047756 -119.221094</geoLocationPoint>"
      }.freeze

      def self.parse_mrt_datacite(mrt_datacite_xml, identifier_value = nil)
        resource = parse_special(mrt_datacite_xml)
        resource.ensure_identifier(identifier_value) if identifier_value
        resource.ensure_resource_type!
        resource.convert_funding!
        resource.fix_breaks!
        resource.inject_rights!
        resource
      end

      def self.parse_special(mrt_datacite_xml)
        raise "Expected Datacite XML string, but was #{mrt_datacite_xml || 'nil'}" unless mrt_datacite_xml && mrt_datacite_xml.respond_to?(:force_encoding)
        datacite_xml = mrt_datacite_xml.force_encoding('utf-8')
        SPECIAL_CASES.each { |regex, replacement| datacite_xml.gsub!(regex, replacement) }
        parse_xml(datacite_xml)
      end

    end
  end
end
