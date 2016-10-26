require 'xml/mapping_extensions'

module Eml
  module Mapping

    FILTER_PATTERNS = [
      %r{<([A-Za-z]+)>No[^<]*provided</\1>},
      %r{<([A-Za-z]+)>No[^<]*described</\1>},
      %r{<([A-Za-z]+)>[^<]*No standard is specified[^<]*</\1>},
      %r{<([A-Za-z]+)>noemail@noemail.com</\1>},
      %r{<([A-Za-z]+)>\s*</\1>},
      %r{<([A-Za-z]+)/>},
      %r{<([A-Za-z]+)>Missing required element</\1>},
    ].freeze

    def self.filter(xml_text)
      utf8_encoded = xml_text.force_encoding('utf-8')
      namespace_ignored = utf8_encoded.gsub(%r{<(/?)eml:eml[^>]*>}, '<\1eml>')
      paras_fixed = namespace_ignored.gsub(%r{<(intellectualRights|funding|abstract)>([^<]+)</\1>}, '<\1><para>\2</para></\1>')
      filtered = FILTER_PATTERNS.inject(paras_fixed) { |xml, pattern| deep_filter(xml, pattern) }
      no_tabs = filtered.tr("\t", ' ')
      no_line_ending_whitespace = no_tabs.gsub(/ *(\n|\r)+/, "\n")
      no_line_ending_whitespace.gsub(/\n+/, "\n")
    end

    def self.deep_filter(text, pattern)
      filtered = text.gsub(pattern, '')
      return filtered if filtered == text
      deep_filter(filtered, pattern)
    end

    class NonBlankTextNode < XML::Mapping::TextNode
      def extract_attr_value(xml)
        attr_value = super
        return unless attr_value
        (stripped = attr_value.strip) == '' ? nil : stripped
      end
    end
    ::XML::Mapping.add_node_class(NonBlankTextNode)

    class ParaContainer # TODO: can we just use qualified XPaths?
      include XML::Mapping
      non_blank_text_node :text, '@text', default_value: nil
      non_blank_text_node :para, 'para', default_value: nil

      def full_text
        texts = [text, para].compact
        return if texts.empty?
        texts.join("\n")
      end
    end

    class IndividualName
      include XML::Mapping
      non_blank_text_node :given_name, 'givenName', default_value: nil
      non_blank_text_node :surname, 'surName', default_value: nil

      def full_name
        return unless surname || given_name
        "#{surname}#{', ' if surname && given_name}#{given_name}"
      end
    end

    class Address
      include XML::Mapping
      non_blank_text_node :delivery_point, 'deliveryPoint', default_value: nil
      non_blank_text_node :city, 'city', default_value: nil
      non_blank_text_node :administrative_area, 'administrativeArea', default_value: nil
      non_blank_text_node :postal_code, 'postalCode', default_value: nil
      non_blank_text_node :country, 'country', default_value: nil
    end

    class Person
      include XML::Mapping
      object_node :individual_name, 'individualName', class: IndividualName, default_value: nil
      non_blank_text_node :organization_name, 'organizationName', default_value: nil
      object_node :address, 'address', class: Address, default_value: nil
      non_blank_text_node :phone, 'phone', default_value: nil
      non_blank_text_node :electronic_mail_address, 'electronicMailAddress', default_value: nil
    end

    class Online
      include XML::Mapping
      non_blank_text_node :url, 'url', default_value: nil
    end

    class Distribution
      include XML::Mapping
      object_node :online, 'online', class: Online, default_value: nil
    end

    class BoundingCoordinates
      include XML::Mapping
      non_blank_text_node :west_bounding_coordinate, 'westBoundingCoordinate', default_value: nil
      non_blank_text_node :east_bounding_coordinate, 'eastBoundingCoordinate', default_value: nil
      non_blank_text_node :north_bounding_coordinate, 'northBoundingCoordinate', default_value: nil
      non_blank_text_node :south_bounding_coordinate, 'southBoundingCoordinate', default_value: nil

      def empty?
        south_bounding_coordinate == north_bounding_coordinate &&
          west_bounding_coordinate == east_bounding_coordinate
      end
    end

    class GeographicCoverage
      include XML::Mapping
      non_blank_text_node :geographic_description, 'geographicDescription', default_value: nil
      object_node :bounding_coordinates, 'boundingCoordinates', class: BoundingCoordinates, default_value: nil
    end

    class DateContainer
      include XML::Mapping
      date_node :calendar_date, 'calendarDate', default_value: nil
    end

    class RangeOfDates
      include XML::Mapping
      object_node :begin_date, 'beginDate', class: DateContainer, default_value: nil
      object_node :end_date, 'endDate', class: DateContainer, default_value: nil

      def range_start
        begin_date && begin_date.calendar_date
      end

      def range_end
        end_date && end_date.calendar_date
      end
    end

    class TemporalCoverage
      include XML::Mapping
      non_blank_text_node :id, '@id', default_value: nil
      object_node :range_of_dates, 'rangeOfDates', class: RangeOfDates, default_value: nil

      def range_start
        range_of_dates && range_of_dates.range_start
      end

      def range_end
        range_of_dates && range_of_dates.range_end
      end
    end

    class Coverage
      include XML::Mapping
      object_node :geographic_coverage, 'geographicCoverage', class: GeographicCoverage, default_value: nil
      object_node :temporal_coverage, 'temporalCoverage', class: TemporalCoverage, default_value: nil
    end

    class Publisher
      include XML::Mapping
      non_blank_text_node :organization_name, 'organizationName', default_value: nil
    end

    class Personnel
      include XML::Mapping
      object_node :individual_name, 'individualName', class: IndividualName, default_value: nil
      non_blank_text_node :organization_name, 'organizationName', default_value: nil
      non_blank_text_node :role, 'role', default_value: nil
    end

    class Project
      include XML::Mapping

      non_blank_text_node :title, 'title', default_value: nil
      object_node :personnel, 'personnel', class: Personnel, default_value: nil
      object_node :abstract, 'abstract', class: ParaContainer, default_value: nil
      object_node :funding, 'funding', class: ParaContainer, default_value: nil
    end

    class DateTime
      include XML::Mapping
      non_blank_text_node :format_string, 'formatString', default_value: nil
    end

    class Unit
      include XML::Mapping
      non_blank_text_node :standard_unit, 'standardUnit', default_value: nil
      non_blank_text_node :custom_unit, 'customUnit', default_value: nil
    end

    class NumericDomain
      include XML::Mapping
      non_blank_text_node :number_type, 'numberType', default_value: nil
    end

    class Interval
      include XML::Mapping

      object_node :unit, 'unit', class: Unit, default_value: nil
      object_node :numeric_domain, 'numericDomain', class: NumericDomain, default_value: nil
    end

    class TextDomain
      include XML::Mapping
      non_blank_text_node :definition, 'definition', default_value: nil
    end

    class NonNumericDomain
      include XML::Mapping
      object_node :text_domain, 'textDomain', class: TextDomain, default_value: nil
    end

    class Nominal
      include XML::Mapping
      object_node :non_numeric_domain, 'nonNumericDomain', class: NonNumericDomain, default_value: nil
    end

    class MeasurementScale
      include XML::Mapping

      object_node :date_time, 'dateTime', class: DateTime, default_value: nil
      object_node :interval, 'interval', class: Interval, default_value: nil
      non_blank_text_node :format_string, 'formatString', default_value: nil
      object_node :nominal, 'nominal', class: Nominal, default_value: nil
    end

    class Attribute
      include XML::Mapping

      non_blank_text_node :attribute_name, 'attributeName', default_value: nil
      non_blank_text_node :attribute_definition, 'attributeDefinition', default_value: nil
      object_node :measurement_scale, 'measurementScale', class: MeasurementScale, default_value: nil
    end

    class DataTable
      include XML::Mapping

      non_blank_text_node :entity_name, 'entityName', default_value: nil
      non_blank_text_node :entity_description, 'entityDescription', default_value: nil
      array_node :attribute_list, 'attributeList', 'attribute', default_value: []
    end

    class Dataset
      include XML::Mapping

      root_element_name 'dataset'

      non_blank_text_node :id, '@id', default_value: nil
      non_blank_text_node :title, 'title', default_value: nil
      object_node :creator, 'creator', class: Person, default_value: nil
      date_node :pub_date, 'pubDate', default_value: nil
      object_node :abstract, 'abstract', class: ParaContainer, default_value: nil
      array_node :keyword_set, 'keywordSet', 'keyword', class: String, default_value: []
      object_node :intellectual_rights, 'intellectualRights', class: ParaContainer, default_value: nil
      object_node :distribution, 'distribution', class: Distribution, default_value: nil
      object_node :coverage, 'coverage', class: Coverage, default_value: nil
      object_node :contact, 'contact', class: Person, default_value: nil
      object_node :publisher, 'publisher', class: Publisher, default_value: nil
      object_node :project, 'project', class: Project, default_value: nil
      object_node :data_table, 'dataTable', class: DataTable, default_value: nil

      def publisher_org_name
        publisher.organization_name if publisher
      end

      def creator_org_name
        creator.organization_name if creator
      end

      def contact_org_name
        contact.organization_name if contact
      end

      def coverage_start
        coverage && (temporal = coverage.temporal_coverage) && temporal.range_start
      end

      def coverage_end
        coverage && (temporal = coverage.temporal_coverage) && temporal.range_end
      end

      def geo_coverage
        coverage && coverage.geographic_coverage
      end

      def abstract_text
        abstract && abstract.full_text
      end

      def rights_text
        intellectual_rights && intellectual_rights.full_text
      end

      def funding
        project && (funding = project.funding) && funding.full_text
      end
    end

    class Metadata
      include XML::Mapping

      non_blank_text_node :description, 'description', default_value: nil
      non_blank_text_node :formatted_citation, 'formattedCitation', default_value: nil
    end

    class AdditionalMetadata
      include XML::Mapping

      non_blank_text_node :describes, 'describes', default_value: 'nil'
      object_node :metadata, 'metadata', class: Metadata, default_value: 'nil'
    end

    class Eml
      include XML::Mapping

      root_element_name 'eml'

      object_node :dataset, 'dataset', class: Dataset, default_value: nil
      array_node :additional_metadata, 'additionalMetadata', class: AdditionalMetadata, default_value: []

      def self.parse_filtered(eml_xml)
        filtered_xml = Mapping.filter(eml_xml)
        parse_xml(filtered_xml)
      end
    end

  end
end
