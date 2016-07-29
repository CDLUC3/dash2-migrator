require 'spec_helper'

module Datacite
  module Mapping
    describe Resource do

      describe '#parse_mrt_datacite' do

        it 'fixes bad contributors'

        it 'creates a FundingReference from a description' do
          datacite_xml = File.read('spec/data/dash1-datacite-xml/dataone-ark+=c5146=r3059p-mrt-datacite.xml')
          resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')

          funding_references = resource.funding_references
          expect(funding_references.size).to eq(1)

          funding_reference = funding_references[0]
          name = funding_reference.name
          expect(name).to eq('National Science Foundation, Division of Atmospheric and Geospace Sciences')
          award_number = funding_reference.award_number.value
          expect(award_number).to eq('AGS-0956425')

          descriptions = resource.descriptions
          others = descriptions.select(&:funding?)
          expect(others.size).to eq(1)

          desc = others[0]
          expect(desc.value).to eq("Data were created with funding from the #{name} under grant #{award_number}.")
        end

        xit 'creates a FundingReference from an OpenAIRE hack' do
          datacite_xml = File.read('spec/data/dash1-datacite-xml/ucm-ark+=b6071=z7wc73-mrt-datacite.xml')
          resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
        end

        xit 'creates multiple references for multiple funders' do
          datacite_xml = File.read('spec/data/dash1-datacite-xml/dataone-ark+=c5146=r36p4t-mrt-datacite.xml')
          resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
        end

      end

      # describe 'special cases' do
      #
      #   attr_reader :descriptions
      #   attr_reader :funders
      #
      #   before(:all) do
      #     funders = {}
      #     File.foreach('/Users/dmoles/Work/dash2-migrator/spec/data/described-funders.txt') do |l|
      #       pathname, contrib_xml = l.split("\t")
      #       funders[pathname] = Datacite::Mapping::Contributor.parse_xml(contrib_xml)
      #     end
      #     @funders = funders.freeze
      #
      #     descriptions = {}
      #     File.foreach('spec/data/descriptions-other.txt') do |l|
      #       pathname, desc_xml = l.split("\t")
      #       descriptions[pathname] = Datacite::Mapping::Description.parse_xml(desc_xml)
      #     end
      #     @descriptions = descriptions.freeze
      #   end
      #
      #   describe 'rights and funding' do
      #
      #     it 'extracts funding information' do
      #       pathnames = funders.keys
      #     end
      #
      #     it 'has the right test data' do
      #       expect(descriptions.size).to eq(funders.size)
      #       funders.keys.each do |k|
      #         expect(descriptions.key?(k)).to be true
      #       end
      #     end
      #
      #     it 'handles missing rights information for UCSF'
      #     it 'handles missing rights information for UC Merced'
      #     xit 'handles oddball rights information' do
      #       # ucla-ark+=b5060=d2qr4v2t-mrt-datacite.xml <rights>RatSCIA materials are free. In order to download the RatSCIA materials, please provide name, affiliation and email address when prompted. Information is gathered for tracking/funding purposes only.</rights>
      #       # ucsf-ark+=b7272=q6bg2kwf-mrt-datacite.xml:<rights>Terms of Use for these data are outlined in the associated Data Use Agreement</rights>
      #     end
      #     it 'handles ucm-ark+=b6071=z7wc73-mrt-datacite.xml'
      #
      #
      #
      #   end
      #
      # end
    end
  end
end
