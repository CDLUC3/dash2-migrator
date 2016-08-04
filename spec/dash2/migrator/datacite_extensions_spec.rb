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

        it 'creates a FundingReference from an identified funder' do
          datacite_xml = File.read('spec/data/dash1-datacite-xml/ucm-ark+=b6071=z7wc73-mrt-datacite.xml')
          resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')

          funding_references = resource.funding_references
          expect(funding_references.size).to eq(1)

          funding_reference = funding_references[0]

          name = funding_reference.name
          expect(name).to eq('National Science Foundation, Division of Earth Sciences, Critical Zone Observatories')

          expect(funding_reference.award_number).to be_nil

          id = funding_reference.identifier
          expect(id).not_to be_nil
          expect(id.value).to eq('http://dx.doi.org/10.13039/100000160')
          expect(id.type).to eq(FunderIdentifierType::OTHER)
        end

        describe 'multiple references for multiple funders' do
          it 'splits on semicolon' do

            cases = {
              'dataone-ark+=c5146=r36p4t-mrt-datacite.xml' => {
                'U.S. Environmental Protection Agency' => 'EPA STAR Fellowship 2011',
                'CYBER-ShARE Center of Excellence National Science Foundation (NSF) CREST grants' => 'HRD-0734825 and HRD-1242122',
                'CI-Team Grant' => 'OCI-1135525'
              },
              'ucsf-ark+=b7272=q6c8276k-mrt-datacite.xml' => {
                'Dept of Veterans Affairs' => 'VA BX001970',
                'National Institutes of Health' => 'NIH RO1 HL31113',
                'Western States Affiliate of the American Heart Association' => nil
              },
              'ucsf-ark+=b7272=q6ms3qnx-mrt-datacite.xml' => [
                ['Bill & Melinda Gates Foundation', 'OPP1086183'],
                ['MacArthur Foundation', '05-84956-000-GSS'],
                ['National Institutes of Health', 'R01HD053129'],
                ['Bill & Melinda Gates Foundation', '48541']
              ]
            }

            cases.each do |file, expected|
              datacite_xml = File.read("spec/data/dash1-datacite-xml/#{file}")
              resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')

              frefs = resource.funding_references
              expect(frefs.size).to eq(expected.size), "Expected #{frefs} (size #{frefs.size}) to have size #{expected.size}"

              funding_descriptions = resource.funding_descriptions
              # funding_descriptions = resource.descriptions.select(&:funding?)
              expect(funding_descriptions.size).to eq(expected.size)

              expected.each_with_index do |(name, award_number), index|
                funding_reference = frefs[index]
                expect(funding_reference.name).to eq(name)
                expect(funding_reference.grant_number).to eq(award_number)

                funding_description = funding_descriptions[index]
                if award_number
                  expect(funding_description.value).to eq("Data were created with funding from the #{name} under grant #{award_number}.")
                else
                  expect(funding_description.value).to eq("Data were created with funding from the #{name}.")
                end
              end
            end
          end
        end

        it 'parses all funder contributors' do
          puts '<all>'
          File.readlines('spec/data/funded-datasets.txt').each do |file|
            datacite_xml = File.read("spec/data/dash1-datacite-xml/#{file.strip}")
            resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
            frefs = resource.funding_references
            expect(frefs).not_to be_empty

            fdescs = resource.funding_descriptions
            expect(fdescs.size).to eq(frefs.size)

            frefs.zip(fdescs) do |fref, fdesc|
              puts '<!-- ____________________________________________________________ -->'
              puts "<!-- #{file.strip} -->"
              puts fref.save_to_xml
              puts fdesc.save_to_xml
              puts
            end
          end
          puts '</all>'
        end

        it 'doesn\'t add funding references to datasets without funder contributors' do
          File.readlines('spec/data/unfunded-datasets.txt').each do |file|
            datacite_xml = File.read("spec/data/dash1-datacite-xml/#{file.strip}")
            resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
            frefs = resource.funding_references
            expect(frefs).to be_empty

            fdescs = resource.funding_descriptions
            expect(fdescs).to be_empty, "Expected no funding descriptions for #{file.strip}, but got: #{fdescs}"
          end
        end

        it 'deletes old grant number descriptions'

        it 'deletes old funders'

      end

      describe 'rights and funding' do
        it 'handles missing rights information for UCSF'
        it 'handles missing rights information for UC Merced'
        xit 'handles oddball rights information' do
          # ucla-ark+=b5060=d2qr4v2t-mrt-datacite.xml <rights>RatSCIA materials are free. In order to download the RatSCIA materials, please provide name, affiliation and email address when prompted. Information is gathered for tracking/funding purposes only.</rights>
          # ucsf-ark+=b7272=q6bg2kwf-mrt-datacite.xml:<rights>Terms of Use for these data are outlined in the associated Data Use Agreement</rights>
        end
        it 'handles ucm-ark+=b6071=z7wc73-mrt-datacite.xml'
      end

      describe 'all documents' do
        xit 'parses them correctly' do
          Dir.glob('spec/data/dash1-datacite-xml') do |f|
            datacite_xml = File.read(f)
            resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
          end
        end
      end
    end
  end
end
