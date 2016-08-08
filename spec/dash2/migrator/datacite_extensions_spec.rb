require 'spec_helper'

module Datacite
  module Mapping
    describe Resource do
      describe '#parse_mrt_datacite' do
        it 'fixes bad contributors'

        it 'injects missing DOIs' do
          datacite_xml = File.read('spec/data/dash1-datacite-xml/dataone-ark+=c5146=r3g591-mrt-datacite.xml')
          injected_value = '10.123/456'
          resource = Resource.parse_mrt_datacite(datacite_xml, injected_value)
          identifier = resource.identifier
          expect(identifier).not_to be_nil
          expect(identifier.identifier_type).to eq('DOI')
          expect(identifier.value).to eq(injected_value)
        end

        it 'preserves existing DOIs' do
          datacite_xml = File.read('spec/data/dash1-datacite-xml/ucm-ark+=13030=m51g217t-mrt-datacite.xml')
          resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
          identifier = resource.identifier
          expect(identifier).not_to be_nil
          expect(identifier.identifier_type).to eq('DOI')
          expect(identifier.value).to eq('10.6071/H8RN35SM')
        end

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
                  if award_number.include?('and')
                    expect(funding_description.value).to eq("Data were created with funding from the #{name} under grants #{award_number}.")
                  else
                    expect(funding_description.value).to eq("Data were created with funding from the #{name} under grant #{award_number}.")
                  end
                else
                  expect(funding_description.value).to eq("Data were created with funding from the #{name}.")
                end
              end
            end
          end
        end

        it 'parses all funder contributors' do
          File.readlines('spec/data/funded-datasets.txt').each do |file|
            datacite_xml = File.read("spec/data/dash1-datacite-xml/#{file.strip}")
            resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
            frefs = resource.funding_references
            expect(frefs).not_to be_empty

            fdescs = resource.funding_descriptions
            expect(fdescs.size).to eq(frefs.size)

            funder_contribs = resource.funder_contribs
            expect(funder_contribs).to be_empty, "Expected no funder contributors for #{file.strip}, but got: #{funder_contribs}"

            # frefs.zip(fdescs) do |fref, fdesc|
            #   puts '<!-- ____________________________________________________________ -->'
            #   puts "<!-- #{file.strip} -->"
            #   puts fref.save_to_xml
            #   puts fdesc.save_to_xml
            #   puts
            # end
          end
        end

        it 'doesn\'t add funding references to datasets without funder contributors' do
          File.readlines('spec/data/all-no-funding.txt').each do |file|
            datacite_xml = File.read("spec/data/dash1-datacite-xml/#{file.strip}")
            resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
            frefs = resource.funding_references
            expect(frefs).to be_empty

            fdescs = resource.funding_descriptions
            expect(fdescs).to be_empty, "Expected no funding descriptions for #{file.strip}, but got: #{fdescs}"
          end
        end
      end

      describe 'rights' do

        it 'handles ucsf-ark+=b7272=q6bg2kwf-mrt-datacite.xml' do
          datacite_xml = File.read('spec/data/dash1-datacite-xml/ucsf-ark+=b7272=q6bg2kwf-mrt-datacite.xml')
          resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
          rights_list = resource.rights_list
          expect(rights_list).to be_an(Array)
          expect(rights_list.size).to eq(1)
          expect(rights_list[0].uri).to eq(Rights::UCSF_FEB_13.uri)
          expect(rights_list[0].value).to eq(Rights::UCSF_FEB_13.value)
        end

        it 'handles ucsf-ark+=b7272=q6057cv6-mrt-datacite.xml' do
          datacite_xml = File.read('spec/data/dash1-datacite-xml/ucsf-ark+=b7272=q6057cv6-mrt-datacite.xml')
          resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
          rights_list = resource.rights_list
          expect(rights_list).to be_an(Array)
          expect(rights_list.size).to eq(1)
          expect(rights_list[0]).to eq(Rights::UCSF_DUA)
        end

        it 'handles ucm-ark+=b6071=z7wc73-mrt-datacite.xml'

        it 'handles rights for all files' do
          expected = {
            'spec/data/dash1-datacite-xml/ucsf-ark+=b7272=q6bg2kwf-mrt-datacite.xml' =>
                Rights::UCSF_FEB_13,
            'spec/data/dash1-datacite-xml/ucm-ark+=13030=m51g217t-mrt-datacite.xml' =>
                  Rights::CC_BY
          }

          File.readlines('spec/data/all-ucsf-dua.txt').each do |f|
            expected["spec/data/dash1-datacite-xml/#{f.strip}"] = Rights::UCSF_DUA
          end
          File.readlines('spec/data/all-cc-zero.txt').each do |f|
            expected["spec/data/dash1-datacite-xml/#{f.strip}"] = Rights::CC_ZERO
          end
          File.readlines('spec/data/all-cc-by.txt').map do |f|
            expected["spec/data/dash1-datacite-xml/#{f.strip}"] = Rights::CC_BY
          end

          aggregate_failures 'all files' do
            Dir.glob('spec/data/dash1-datacite-xml/*.xml').sort.each do |f|

              datacite_xml = File.read(f)
              resource = Resource.parse_mrt_datacite(datacite_xml, '10.123/456')

              rights_list = resource.rights_list
              expect(rights_list).not_to be_nil, "Expected #{f} to have rights information, but it didn't"

              expect(rights_list.size).to eq(1), "Expected #{f} to have 1 <rights/> tag, but found #{rights_list.size}"
              rights = rights_list[0]
              expect(rights).not_to be_nil, "Expected #{f} to have rights information, but it didn't"
              next unless rights # TODO: Remove once we disaggregate failures

              expect(rights).to be_a(Rights), "Expected #{f} to have Rights, but found #{rights}"
              expect(rights.uri).not_to be_nil, "Expected #{f} to have a rights URI, but it didn't"
              expect(rights.value).not_to be_nil, "Expected #{f} to have a rights value, but it didn't"

              expect(expected.key?(f)).to be_truthy, "No expected value for #{f}"
              next unless expected[f] # TODO: Remove once we disaggregate failures
              expected_uri = expected[f].uri
              expected_value = expected[f].value
              expect(rights.uri).to eq(expected_uri), "Expected #{f} to have rights URI [#{expected_uri}], but got [#{rights.uri}]"
              expect(rights.value).to eq(expected_value), "Expected #{f} to have rights value '#{expected_value}', but got '#{rights.value}'"
            end
          end
        end

        it 'uses real URLs for UCSF DUAs'

      end

    end
  end
end
