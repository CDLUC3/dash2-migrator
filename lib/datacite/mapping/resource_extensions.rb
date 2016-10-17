require 'datacite/mapping'

module Datacite
  module Mapping

    class Resource
      def funder_contribs
        contributors.select { |c| c.type == ContributorType::FUNDER }
      end

      def funding_descriptions
        descriptions.select { |desc| desc.type == DescriptionType::OTHER && !desc.value.start_with?('Lower and upper Providence Creek') }
      end

      def ensure_identifier(identifier_value)
        existing_ident_value = identifier && identifier.value
        if existing_ident_value
          warn("Preserving existing identifier #{existing_ident_value}; ignoring new value #{"'#{identifier_value}'" || 'nil'}") unless existing_ident_value == identifier_value
        else
          inject_identifier!(identifier_value)
        end
      end

      def ensure_resource_type!
        self.resource_type = ResourceType.new(resource_type_general: ResourceTypeGeneral::OTHER) unless resource_type
      end

      # Converts deprecated funder contributors to FundingReferences
      def convert_funding!
        funder_contribs.zip(funding_descriptions) do |funder_contrib, funding_desc|
          contributors.delete(funder_contrib)
          descriptions.delete(funding_desc)
          all_names, all_grants = names_and_grants(funder_contrib, funding_desc)
          all_names.zip(all_grants).each { |funder_name, grant_number| add_funding_reference(funder_contrib, funder_name, grant_number) }
        end
      end

      def fix_breaks!
        descriptions.each { |d| d.value.gsub!("\n", '<br/>') }
      end

      def add_funding_reference(funder_contrib, funder_name, grant_number)
        award_number = grant_number && grant_number != 'nil' && grant_number !~ /^\s*$/ ? grant_number : nil
        fref = FundingReference.new(name: funder_name, identifier: identifier_for(funder_contrib), award_number: award_number)
        funding_references << fref
        descriptions << fref.to_description
      end

      def inject_rights!
        return if rights_list && !rights_list.empty?
        if publisher == 'University of California, San Francisco'
          self.rights_list = [Rights::UCSF_DUA]
        elsif identifier && identifier.value == '10.6071/H8RN35SM'
          self.rights_list = [Rights::CC_BY]
        end
      end

      def self.to_identifier(identifier_value)
        if ARK_PATTERN.match(identifier_value)
          identifier = Datacite::Mapping::Identifier.new(value: identifier_value)
          identifier.identifier_type = 'ARK' # allowed by EZID, if not Datacite
          return identifier
        elsif (doi_match_data = DOI_PATTERN.match(identifier_value))
          return Datacite::Mapping::Identifier.new(value: doi_match_data[0])
        end
        warn("Identifier value #{"'#{identifier_value}'" || 'nil'} does not appear to be a DOI or ARK; ignoring")
        nil
      end

      private

      def inject_identifier!(identifier_value)
        ident = Resource.to_identifier(identifier_value)
        self.identifier = ident if ident
      end

      def names_and_grants(funder_contrib, funding_desc)
        funder_contrib_name = funder_contrib.name.strip
        funding_desc_value = funding_desc && funding_desc.value
        return [[funder_contrib_name], []] unless funding_desc_value
        grant_numbers = funding_desc_value.split(';').map { |s| s.strip.chomp(',') }
        funder_names = funder_contrib_name.split(';').map(&:strip)
        grant_numbers.size == funder_names.size ? [funder_names, grant_numbers] : [[funder_contrib_name], [funding_desc_value]]
      end

      def identifier_for(funder_contrib)
        funder_name_id = funder_contrib.identifier
        return unless funder_name_id
        funder_id_scheme = funder_name_id.scheme
        funder_id_type = FunderIdentifierType.find_by_value_str(funder_id_scheme) || FunderIdentifierType::OTHER
        FunderIdentifier.new(type: funder_id_type, value: funder_name_id.value)
      end
    end
  end
end
