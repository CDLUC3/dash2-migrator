require 'spec_helper'
require 'eml/mapping'

module Eml
  module Mapping

    describe IndividualName do
      describe '#full_name' do
        it 'assembles full names' do
          name = IndividualName.new
          name.given_name = 'Given'
          name.surname = 'Sur'
          expect(name.full_name).to eq('Sur, Given')
        end
        it 'handles missing given names' do
          name = IndividualName.new
          name.surname = 'Sur'
          expect(name.full_name).to eq('Sur')
        end
        it 'handles missing surnames' do
          name = IndividualName.new
          name.given_name = 'Given'
          expect(name.full_name).to eq('Given')
        end
        it 'handles missing names' do
          name = IndividualName.new
          expect(name.full_name).to be_nil
        end
      end
    end

    describe Dataset do

      it 'round-trips a file' do
        f = 'spec/data/eml/dash1-eml-xml/dataone-ark+=90135=q1057cwm-mrt-eml.xml'
        eml_xml = File.binread(f)

        expect(eml_xml).not_to be_nil, "File.binread('#{f}') returned nil"
        expect(eml_xml.strip).not_to eq(''), "File.binread('#{f}') returned blank"

        eml = Eml.parse_filtered(eml_xml)
        output_xml = eml.write_xml

        filtered_xml = Mapping.filter(eml_xml)
        filtered_output_xml = Mapping.filter(output_xml)
        expect(filtered_output_xml).to be_xml(filtered_xml, f)
      end

      it 'round-trips all files' do
        aggregate_failures 'all files' do
          Dir.glob('spec/data/eml/dash1-eml-xml/*.xml').sort.each do |f|
            eml_xml = File.binread(f)

            expect(eml_xml).not_to be_nil, "File.binread('#{f}') returned nil"
            expect(eml_xml.strip).not_to eq(''), "File.binread('#{f}') returned blank"

            eml = Eml.parse_filtered(eml_xml)
            output_xml = eml.write_xml

            filtered_xml = Mapping.filter(eml_xml)
            filtered_output_xml = Mapping.filter(output_xml)
            expect(filtered_output_xml).to be_xml(filtered_xml, f)
          end
        end
      end

      describe '#rights_text' do
        it 'extracts the text' do
          f = 'spec/data/eml/dash1-eml-xml/dataone-ark+=90135=q13j39xf-mrt-eml.xml'
          eml_xml = File.binread(f)
          eml = Eml.parse_filtered(eml_xml)
          dataset = eml.dataset
          expect(dataset.rights_text).to eq('Creative Commons Zero License')
        end
      end

    end
  end
end
