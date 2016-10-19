require 'eml/mapping'
require 'datacite/mapping'
require 'datacite/mapping/datacite_extensions'

module Datacite
  module Mapping
    class Rights
      CC_BY_3 = Rights.new(
        uri: URI('https://creativecommons.org/licenses/by/3.0/'),
        value: 'Creative Commons Attribution 3.0 International (CC BY 3.0)'
      )
    end
  end
end

module Dash2
  module Migrator
    module Harvester
      class EmlDataciteMapper # rubocop:disable Metrics/ClassLength
        include Datacite::Mapping

        attr_reader :dataset
        attr_reader :ident_value

        def initialize(dataset:, ident_value:)
          @dataset = dataset
          @ident_value = ident_value
        end

        def self.to_datacite(eml_xml, id_value)
          dataset = Eml::Mapping::Eml.parse_filtered(eml_xml).dataset
          mapper = EmlDataciteMapper.new(dataset: dataset, ident_value: id_value)
          mapper.to_datacite
        end

        def to_datacite # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          @datacite_resource ||= Resource.new(
            identifier: identifier,
            creators: [creator],
            titles: titles,
            publisher: publisher,
            publication_year: publication_year,
            dates: dates,
            descriptions: descriptions,
            subjects: dataset.keyword_set.map { |kw| Subject.new(value: kw) },
            rights_list: [rights],
            alternate_identifiers: url_alt_ident ? [url_alt_ident] : [],
            geo_locations: location ? [location] : [],
            funding_references: fundref ? [fundref] : []
          )
        end

        def identifier
          # we ignore any dataset ID attributes since they're either junk (fake DOIs)
          # or redundant (same ARK we already have), and 98% don't have them anyway
          Resource.to_identifier(ident_value)
        end

        def creator
          individual_name = eml_creator.individual_name
          Creator.new(
            name: individual_name.full_name,
            given_name: individual_name.given_name,
            family_name: individual_name.surname,
            identifier: creator_identifier,
            affiliations: creator_org_name ? [creator_org_name] : []
          )
        end

        def creator_identifier
          return unless creator_email
          NameIdentifier.new(scheme: 'email', value: "mailto:#{creator_email}")
        end

        def creator_org_name
          @creator_org_name ||= eml_creator.organization_name
        end

        def creator_email
          @creator_email ||= eml_creator.electronic_mail_address
        end

        def eml_creator
          @eml_creator ||= dataset.creator
        end

        def titles
          [(Title.new(value: dataset.title) if dataset.title)].compact
        end

        def publisher
          [:publisher_org_name, :creator_org_name, :contact_org_name].each do |method|
            if (org_name = dataset.send(method))
              return org_name
            end
          end
          fallback_publisher
        end

        def fallback_publisher
          # special cases
          return 'IFCA' if creator_email =~ /ifca\.unican\.es/
          return 'Cornell University' if creator_email =~ /cornell\.edu/
          return 'Universidad Popular Autónoma del Estado de Puebla' if 'victorcuevasv@gmail.com' == creator_email
          return 'University of Tennessee, Knoxville' if %w(
            wbirch@utk.edu
            benbirch7@gmail.com
          ).include?(creator_email)
          'DataONE'
        end

        def pub_date
          dataset.pub_date
        end

        def publication_year
          pub_date.year
        end

        def dates
          @dates ||= begin
            dates = [Date.new(type: DateType::AVAILABLE, value: pub_date)]
            add_coverage(dates)
            dates
          end
        end

        def add_coverage(dates)
          range_start = dataset.coverage_start
          range_end = dataset.coverage_end
          return unless range_start || range_end

          iso_range = range_start ? "#{range_start.xmlschema}/" : ''
          iso_range << range_end.xmlschema if range_end
          dates << Date.new(type: DateType::COLLECTED, value: iso_range)
        end

        def descriptions
          @descriptions ||= begin
            descriptions = []
            descriptions << Description.new(type: DescriptionType::ABSTRACT, value: abstract) if abstract
            descriptions
          end
        end

        def abstract
          dataset.abstract_text
        end

        def rights
          @rights ||= begin
            rights_text = dataset.rights_text
            return Rights::CC_BY_3 if 'creative commons license' == rights_text
            Rights::CC_ZERO
          end
        end

        def url_alt_ident
          return unless @url_alt_ident || ((dist = dataset.distribution) && (online = dist.online) && (url = online.url))
          @url_alt_ident ||= begin
            AlternateIdentifier.new(type: 'URL', value: url)
          end
        end

        def location
          return unless @location || (geo_coverage = dataset.geo_coverage)
          @location ||= begin
            loc = GeoLocation.new(place: geo_coverage.geographic_description)
            if (coords = geo_coverage.bounding_coordinates)
              loc.box = to_box(coords)
            end
            loc
          end
        end

        def to_box(coords)
          GeoLocationBox.new(
            south_latitude: coords.south_bounding_coordinate.to_f,
            west_longitude: coords.west_bounding_coordinate.to_f,
            north_latitude: coords.north_bounding_coordinate.to_f,
            east_longitude: coords.east_bounding_coordinate.to_f
          )
        end

        def fundref
          return unless @funding || (funding = dataset.funding)
          @fundref ||= begin
            FundingReference.new(name: funding)
          end
        end
      end
    end
  end
end
