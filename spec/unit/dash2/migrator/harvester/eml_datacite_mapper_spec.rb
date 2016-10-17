require 'spec_helper'
require 'eml/mapping'

module Dash2
  module Migrator
    module Harvester
      describe EmlDataciteMapper do

        def to_ark(filename)
          pattern = /ark\+=([^=]+)=([^-]+)/
          match_data = pattern.match(filename)
          "ark:/#{match_data[1]}/#{match_data[2]}"
        end

        it 'maps all files' do
          aggregate_failures 'all files' do
            Dir.glob('spec/data/eml/dash1-eml-xml/*.xml').sort.each do |f|
              id_value = to_ark(f)

              eml_xml = File.binread(f)
              eml = Eml::Mapping::Eml.parse_filtered(eml_xml)
              dataset = eml.dataset
              mapper = EmlDataciteMapper.new(
                dataset: dataset,
                ident_value: id_value
              )

              expect(mapper.publisher).not_to be_nil, "Missing publisher for #{f}"
              next unless mapper.publisher

              resource = mapper.to_datacite

              expect(resource).to be_a(Datacite::Mapping::Resource)
              next unless resource.is_a?(Datacite::Mapping::Resource)

              identifier = resource.identifier
              expect(identifier).not_to be_nil
              next unless identifier

              expect(identifier.value).to eq(id_value)

              date_available = resource.dates.find { |d| d.type == Datacite::Mapping::DateType::AVAILABLE }
              expect(date_available).not_to be_nil
              next unless date_available

              expect(resource.publication_year).to eq(date_available.date_value.year)

              if dataset.coverage && dataset.coverage.temporal_coverage
                date_collected = resource.dates.find { |d| d.type == Datacite::Mapping::DateType::COLLECTED }
                expect(date_collected.range_start.date).to eq(dataset.coverage_start)
                expect(date_collected.range_end.date).to eq(dataset.coverage_end)
              end

              if dataset.abstract_text
                abstract = resource.descriptions.find { |d| d.type = Datacite::Mapping::DescriptionType::ABSTRACT }
                expect(abstract.value).to eq(dataset.abstract_text)
              end

              expect(resource.subjects.map(&:value)).to eq(dataset.keyword_set.map(&:strip))

              rights = resource.rights_list[0]
              expect(rights).not_to be_nil, "No rights in #{f}"
              next unless rights

              if f == 'spec/data/eml/dash1-eml-xml/dataone-ark+=90135=q1930r39-mrt-eml.xml'
                expect(rights).to eq(Datacite::Mapping::Rights::CC_BY_3)
              else
                expect(rights).to eq(Datacite::Mapping::Rights::CC_ZERO)
              end
            end
          end
        end
      end
    end
  end
end
