require 'spec_helper'
require 'eml/mapping'

module Eml
  module Mapping
    describe Dataset do

      it 'round-trips a file' do
        f = 'spec/data/eml/dash1-eml-xml/dataone-ark+=90135=q1057cwm-mrt-eml.xml'
        eml_xml = File.binread(f)

        expect(eml_xml).not_to be_nil, "File.binread('#{f}') returned nil"
        expect(eml_xml.strip).not_to eq(''), "File.binread('#{f}') returned blank"

        filtered_xml = Mapping.filter(eml_xml)

        dataset = Eml.parse_xml(filtered_xml)
        output_xml = dataset.write_xml

        filtered_output_xml = Mapping.filter(output_xml)
        expect(filtered_output_xml).to be_xml(filtered_xml, f)
      end

      it 'round-trips all files' do
        aggregate_failures 'all files' do
          Dir.glob('spec/data/eml/dash1-eml-xml/*.xml').sort.each do |f|
            eml_xml = File.binread(f)

            expect(eml_xml).not_to be_nil, "File.binread('#{f}') returned nil"
            expect(eml_xml.strip).not_to eq(''), "File.binread('#{f}') returned blank"

            filtered_xml = Mapping.filter(eml_xml)

            dataset = Eml.parse_xml(filtered_xml)
            output_xml = dataset.write_xml

            filtered_output_xml = Mapping.filter(output_xml)
            expect(filtered_output_xml).to be_xml(filtered_xml, f)
          end
        end
      end
    end
  end
end
