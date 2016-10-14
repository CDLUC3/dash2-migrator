require 'spec_helper'
require 'eml/mapping'

module Eml
  module Mapping
    describe Dataset do
      it 'round-trips all files' do
        aggregate_failures 'all files' do
          Dir.glob('spec/data/eml/dash1-eml-xml/*.xml').sort.each do |f|
            eml_xml = File.read(f)
            dataset = Dataset.parse_xml(eml_xml)
            expect(dataset.write_xml).to be_xml(eml_xml)
          end
        end
      end
    end
  end
end
