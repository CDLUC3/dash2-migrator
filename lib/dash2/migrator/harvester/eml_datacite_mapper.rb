require 'eml/mapping'
require 'datacite/mapping'
require 'datacite/mapping/datacite_extensions'

module Dash2
  module Migrator
    module Harvester
      class EmlDataciteMapper
        include Datacite::Mapping

        attr_reader :dataset
        attr_reader :ident_value

        def initialize(dataset:, ident_value:)
          @dataset = dataset
          @ident_value = ident_value
        end

        def to_datacite
          Resource.new(
            identifier: identifier,
            creators: [creator],
            titles: titles,
            publisher: publisher,
            publication_year: publication_year,
            dates: dates
          )
        end

        def identifier
          # we ignore any dataset ID attributes since they're either junk (fake DOIs)
          # or redundant (same ARK we already have), and 98% don't have them anyway
          Resource.to_identifier(ident_value)
        end

        def non_blank(s)
          return unless s
          (stripped = s.strip) == '' ? nil : stripped
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
          # special cases
          return 'IFCA' if /ifca\.unican\.es/.match(creator_email)
          return 'Cornell University' if /cornell\.edu/.match(creator_email)
          return 'Universidad Popular Autónoma del Estado de Puebla' if 'victorcuevasv@gmail.com' == creator_email
          return 'University of Tennessee, Knoxville' if %w(
            wbirch@utk.edu
            benbirch7@gmail.com
          ).include?(creator_email)
          return 'DataONE' if %w(
            Bupt.aajjnn@gmail.com
            sebastian.nizan@googlemail.com
            janakiramreddy3@gmail.com
          ).include?(creator_email)
          nil
        end

        def pub_date
          dataset.pub_date
        end

        def publication_year
          pub_date.year
        end

        def dates
          dates = [
            Date.new(type: DateType::AVAILABLE, value: pub_date)
          ]

          range_start = dataset.coverage_start
          range_end = dataset.coverage_end

          if range_start || range_end
            iso_range = range_start ? "#{range_start.xmlschema}/" : ''
            iso_range << range_end.xmlschema if range_end
            dates << Date.new(type: DateType::COLLECTED, value: iso_range)
          end

          dates
        end

      end
    end
  end
end
