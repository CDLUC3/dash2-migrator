require 'spec_helper'
require 'eml/mapping'

module Dash2
  module Migrator
    module Harvester
      describe EmlDataciteMapper do

        attr_reader :id_to_dataset
        attr_reader :id_to_mapper
        attr_reader :id_to_resource

        before(:all) do
          id_to_dataset = {}
          id_to_mapper = {}
          id_to_resource = {}
          Dir.glob('spec/data/eml/dash1-eml-xml/*.xml').sort.each do |f|
            id_value = to_ark(f)
            eml_xml = File.binread(f)
            eml = Eml::Mapping::Eml.parse_filtered(eml_xml)

            dataset = eml.dataset
            mapper = EmlDataciteMapper.new(
              dataset: dataset,
              ident_value: id_value
            )

            resource = mapper.to_datacite

            id_to_dataset[id_value] = dataset
            id_to_mapper[id_value] = mapper
            id_to_resource[id_value] = resource
          end

          @id_to_dataset = id_to_dataset.freeze
          @id_to_mapper = id_to_mapper.freeze
          @id_to_resource = id_to_resource.freeze
        end

        def to_ark(filename)
          pattern = /ark\+=([^=]+)=([^-]+)/
          match_data = pattern.match(filename)
          "ark:/#{match_data[1]}/#{match_data[2]}"
        end

        it 'extracts the publisher' do
          aggregate_failures 'all files' do
            id_to_dataset.keys.each do |id_value|
              mapper = id_to_mapper[id_value]
              expect(mapper.publisher).not_to be_nil, "Missing publisher for #{id_value}"
            end
          end
        end

        it 'creates a writable resource' do
          aggregate_failures 'all files' do
            id_to_dataset.keys.each do |id_value|
              resource = id_to_resource[id_value]
              expect(resource).to be_a(Datacite::Mapping::Resource), "Expected resource for #{id_value}, got #{resource || 'nil'}"
              expect(resource.save_to_xml).to be_a(REXML::Element)
            end
          end
        end

        it 'sets the resource type' do
          aggregate_failures 'all files' do
            id_to_dataset.keys.each do |id_value|
              resource = id_to_resource[id_value]
              expect(resource.resource_type).not_to be_nil
            end
          end
        end

        it 'sets the identifier' do
          aggregate_failures 'all files' do
            id_to_dataset.keys.each do |id_value|
              resource = id_to_resource[id_value]
              identifier = resource.identifier

              expect(identifier).not_to be_nil
              next unless identifier

              expect(identifier.value).to eq(id_value)
            end
          end
        end

        it 'sets the date available and publication year' do
          aggregate_failures 'all files' do
            id_to_dataset.keys.each do |id_value|
              resource = id_to_resource[id_value]
              date_available = resource.dates.find { |d| d.type == Datacite::Mapping::DateType::AVAILABLE }
              expect(date_available).not_to be_nil, "Missing date available for #{id_value}"
              next unless date_available
              expect(resource.publication_year).to eq(date_available.date_value.year), "Wrong pubyear for #{id_value}"
            end
          end
        end

        it 'sets the date collected' do
          aggregate_failures 'all files' do
            id_to_dataset.each do |id_value, dataset|
              resource = id_to_resource[id_value]
              next unless dataset.coverage && dataset.coverage.temporal_coverage
              date_collected = resource.dates.find { |d| d.type == Datacite::Mapping::DateType::COLLECTED }
              expect(date_collected).not_to be_nil
              next unless date_collected
              expect(date_collected.range_start.date).to eq(dataset.coverage_start)
              expect(date_collected.range_end.date).to eq(dataset.coverage_end)
            end
          end
        end

        it 'extracts the abstract' do
          aggregate_failures 'all files' do
            id_to_dataset.each do |id_value, dataset|
              resource = id_to_resource[id_value]
              next unless dataset.abstract_text
              abstract = resource.descriptions.find { |d| d.type = Datacite::Mapping::DescriptionType::ABSTRACT }
              expect(abstract).not_to be_nil
              next unless abstract
              expect(abstract.value).to eq(dataset.abstract_text)
            end
          end
        end

        it 'extracts the subjects' do
          aggregate_failures 'all files' do
            id_to_dataset.each do |id_value, dataset|
              resource = id_to_resource[id_value]
              expect(resource.subjects.map(&:value)).to eq(dataset.keyword_set.map(&:strip))
            end
          end
        end

        it 'sets the rights' do
          aggregate_failures 'all files' do
            id_to_dataset.keys.each do |id_value|
              resource = id_to_resource[id_value]
              rights = resource.rights_list[0]
              expect(rights).not_to be_nil, "No rights in #{id_value}"
              next unless rights

              if id_value == 'ark:/90135/q1930r39'
                expect(rights).to eq(Datacite::Mapping::Rights::CC_BY_3)
              else
                expect(rights).to eq(Datacite::Mapping::Rights::CC_ZERO)
              end
            end
          end
        end

        it 'sets alternate identifiers' do
          aggregate_failures 'all files' do
            id_to_dataset.each do |id_value, dataset|
              next unless (dist = dataset.distribution) && (online = dist.online) && (url = online.url)

              resource = id_to_resource[id_value]
              alt_ident_values = resource.alternate_identifiers.select { |id| id.type == 'URL' }.map(&:value)
              expect(alt_ident_values).to include(url), "Missing alternate URL #{url} for #{id_value}"
            end
          end
        end

        describe 'geolocations' do
          it 'sets place names' do
            aggregate_failures 'all files' do
              id_to_dataset.each do |id_value, dataset|
                next unless (coverage = dataset.coverage) && (geo_coverage = coverage.geographic_coverage)
                next unless (place = geo_coverage.geographic_description)
                resource = id_to_resource[id_value]
                locs = resource.geo_locations
                expect(locs.size).to eq(1), "Wrong number of geolocations for #{id_value}; expected 1, was #{locs.size}"
                next unless locs.size == 1
                expect(locs[0].place).to eq(place)
              end
            end
          end
          it 'sets bounding boxes' do
            aggregate_failures 'all files' do
              id_to_dataset.each do |id_value, dataset|
                next unless (coverage = dataset.coverage) && (geo_coverage = coverage.geographic_coverage)
                next unless (coords = geo_coverage.bounding_coordinates)
                resource = id_to_resource[id_value]
                locs = resource.geo_locations
                if coords.empty?
                  next if locs.empty?
                  expect(locs[0].box).to be_nil, "Box created for empty coordinates in #{id_value}"
                else
                  expect(locs.size).to eq(1), "Wrong number of geolocations for #{id_value}; expected 1, was #{locs.size}"
                  next unless locs.size == 1

                  expect(box = locs[0].box).not_to be_nil, "Missing geolocationbox for #{id_value}"
                  next unless box

                  expected_coords = if (place = locs[0].place) && place.include?('Cuerda del Pozo')
                                      {
                                        south_latitude: 41.82,
                                        west_longitude: -2.81,
                                        north_latitude: 41.9,
                                        east_longitude: -2.70
                                      }
                                    else
                                      {
                                        south_latitude: coords.send(:south_bounding_coordinate).to_f,
                                        north_latitude: coords.send(:north_bounding_coordinate).to_f,
                                        west_longitude: coords.send(:west_bounding_coordinate).to_f,
                                        east_longitude: coords.send(:east_bounding_coordinate).to_f
                                      }
                                    end

                  expected_coords.each do |coord, expected|
                    actual = box.send(coord)
                    expect(actual).to eq(expected), "incorrect #{coord} for #{id_value}: expected #{expected}, was #{actual}"
                  end
                end
              end
            end
          end
        end

        it 'creates funding references' do
          aggregate_failures 'all files' do
            id_to_dataset.each do |id_value, dataset|
              next unless (funding = dataset.funding)

              resource = id_to_resource[id_value]
              fundrefs = resource.funding_references

              expect(fundrefs).not_to be_nil
              next unless fundrefs

              expect(fundrefs.size).to eq(1)
              next unless fundrefs.size == 1

              fundref = fundrefs[0]
              expect(fundref.name).to eq(funding)
            end
          end
        end
      end
    end
  end
end
