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
              eml_xml = File.binread(f)
              eml = Eml::Mapping::Eml.parse_filtered(eml_xml)
              id_value = to_ark(f)
              mapper = EmlDataciteMapper.new(
                dataset: eml.dataset,
                ident_value: id_value
              )

              expect(mapper.publisher).not_to be_nil, "Missing publisher for #{f}"
              next unless mapper.publisher

              begin
                resource = mapper.to_datacite
              rescue => e
                e.message << " (#{f})"
                raise
              end
              expect(resource).to be_a(Datacite::Mapping::Resource)
              expect(resource.identifier.value).to eq(id_value)
            end
          end
        end
      end
    end
  end
end
