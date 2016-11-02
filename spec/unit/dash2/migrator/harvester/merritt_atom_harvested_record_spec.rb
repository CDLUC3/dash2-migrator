require 'spec_helper'
require 'webmock/rspec'

module Dash2
  module Migrator
    module Harvester
      describe MerrittAtomHarvestedRecord do
        attr_reader :config
        attr_reader :record
        attr_reader :mrt_mom_uri
        attr_reader :mrt_mom_txt
        attr_reader :feed_uri
        attr_reader :entry

        def wrapper
          record.as_wrapper
        end

        def user_provider
          @config.user_provider
        end

        before(:all) do
          WebMock.disable_net_connect!
        end

        before(:each) do
          base_feed_uri = 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd'
          tenant_path = File.absolute_path('config/tenants/example.yml')
          @config = MerrittAtomSourceConfig.new(user_provider: UserProvider.new('config/dash1_records_users.txt'), tenant_path: tenant_path, feed_uri: base_feed_uri, env_name: 'test')

          @mrt_mom_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr36p4t/2/system%2Fmrt-mom.txt"
          @mrt_mom_txt = File.read('spec/data/harvester/mrt-mom.txt')
          stub_request(:get, mrt_mom_uri).to_return(body: mrt_mom_txt)

          @feed_uri = config.feed_uri
          entry_xml = File.read('spec/data/harvester/entry-r36p4t.xml')
          @entry = RSS::Parser.parse(entry_xml, false).items[0]
          @record = MerrittAtomHarvestedRecord.new(user_provider, 'example', feed_uri, entry)
        end

        describe '#identifier' do
          it 'extracts the identifier' do
            expect(record.identifier).to eq('http://n2t.net/ark:/c5146/r36p4t')
          end
        end

        describe '#timestamp' do
          it 'extracts the timestamp' do
            expect(record.timestamp).to eq(Time.parse('2015-08-17T13:08:15+00:00'))
          end
        end

        describe '#mrt_eml' do
          it 'returns nil for a non-EML record' do
            expect(record.mrt_eml).to be_nil
          end
        end

        describe '#local_id' do
          it 'extracts the local id' do
            expect(record.local_id).to eq('oangdfazln')
          end
        end

        describe '#user_uid' do
          it 'gets the user info from Dash 1'
          it 'creates a user if needed'
          it 'doesn\'t create duplicate users'
          it 'throws NoMethodError for now till we get the above finished' do
            expect { record.user_uid }.to raise_error(NoMethodError)
          end
        end

        describe 'error handling' do
          it 'forwards errors' do
            datacite_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr36p4t/2/producer%2Fmrt-datacite.xml"
            stub_request(:get, datacite_uri).to_return(status: 404)
            expect { record.as_wrapper }.to raise_error(RestClient::NotFound)
          end

          it "fails if there's neither datacite nor EML" do
            allow(record).to receive(:mrt_eml).and_return(nil)
            allow(record).to receive(:mrt_datacite_xml).and_return(nil)
            allow(record).to receive(:mrt_mom).and_return(mrt_mom_txt)
            expect { record.as_wrapper }.to raise_error { |e|
              expect(e.message).to include(record.identifier_value)
            }
          end
        end

        describe 'DOI handling' do
          it 'extracts the DOI from mrt-mom.txt' do
            datacite_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr36p4t/2/producer%2Fmrt-datacite.xml"
            stub_request(:get, datacite_uri).to_return(body: File.read('spec/data/harvester/mrt-datacite.xml'))

            sw_ident = wrapper.identifier
            expect(sw_ident.value).to eq('10.15146/R3RG6G')
          end

          it 'normalizes DOIs' do
            mrt_mom_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr36p4t/2/system%2Fmrt-mom.txt"
            stub_request(:get, mrt_mom_uri).to_return(body: File.read('spec/data/harvester/mrt-mom-q6bg2kwf.txt'))

            datacite_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr36p4t/2/producer%2Fmrt-datacite.xml"
            stub_request(:get, datacite_uri).to_return(body: File.read('spec/data/datacite/dash1-datacite-xml/ucsf-ark+=b7272=q6bg2kwf-mrt-datacite.xml'))

            dcs_resource = wrapper.datacite_resource
            dcs_ident = dcs_resource.identifier

            sw_ident = wrapper.identifier
            expect(sw_ident.value).to eq(dcs_ident.value)
          end
        end

        describe '#stash_wrapper' do

          before(:each) do
            datacite_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr36p4t/2/producer%2Fmrt-datacite.xml"
            stub_request(:get, datacite_uri).to_return(body: File.read('spec/data/harvester/mrt-datacite.xml'))
          end

          it 'creates a StashWrapper' do
            expect(wrapper).to be_a(Stash::Wrapper::StashWrapper)
          end

          it 'sets the identifier to the DOI from mrt-mom.txt' do
            stub_request(:get, mrt_mom_uri).to_return(body: File.read('spec/data/harvester/mrt-mom.txt'))
            @record = MerrittAtomHarvestedRecord.new(user_provider, 'example', feed_uri, entry)
            identifier = wrapper.identifier
            expect(identifier.value).to eq('10.15146/R3RG6G')
            expect(identifier.type).to eq(Stash::Wrapper::IdentifierType::DOI)
          end

          it 'sets the identifier to the ARK from mrt-mom.txt when the DOI is not present' do
            stub_request(:get, mrt_mom_uri).to_return(body: File.read('spec/data/harvester/eml/mrt-mom.txt'))
            @record = MerrittAtomHarvestedRecord.new(user_provider, 'example', feed_uri, entry)
            identifier = wrapper.identifier
            expect(identifier.value).to eq('ark:/90135/q1f769jn')
            expect(identifier.type).to eq(Stash::Wrapper::IdentifierType::ARK)
          end

          it 'sets the embargo date based on the atom <published> tag' do
            embargo = wrapper.embargo
            expect(embargo).not_to be_nil
            expect(embargo.type).to be(Stash::Wrapper::EmbargoType::NONE)
            expect(embargo.period).to eq('none')
            expected_date = Date.new(2015, 8, 16)
            expect(embargo.start_date).to eq(expected_date)
            expect(embargo.end_date).to eq(expected_date)
          end

          it 'sets the wrapped datacite embargo date based on the atom <published> tag' do
            datacite_xml = wrapper.stash_descriptive[0]
            resource = Datacite::Mapping::Resource.parse_xml(datacite_xml)
            dates = resource.dates
            expect(dates.size).to eq(1)
            date = dates[0]
            expect(date.type).to eq(Datacite::Mapping::DateType::AVAILABLE)
            expect(date.value).to eq('2015-08-16T10:57:26+00:00')
          end

          it 'extracts the file inventory' do
            text_plain = MIME::Type.new('text/plain')
            text_csv = MIME::Type.new('text/csv')
            application_openxml = MIME::Type.new('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
            application_pdf = MIME::Type.new('application/pdf')

            expected = [
              {
                title: 'producer/survey_Q11-23_sensors_platforms.R',
                length: 26_414,
                type: text_plain
              },
              {
                title: 'producer/survey_Q25-32_data_metadata_management.R',
                length: 9794,
                type: text_plain
              },
              {
                title: 'producer/survey_Q10_research_sites.R',
                length: 1180,
                type: text_plain
              },
              {
                title: 'producer/clean_survey_data_no_ids.csv',
                length: 320_890,
                type: text_csv
              },
              {
                title: 'producer/survey_Q3-9_respondent_info.R',
                length: 13_784,
                type: text_plain
              },
              {
                title: 'producer/Laney_IRBProposal.docx',
                length: 1_097_848,
                type: application_openxml
              },
              {
                title: 'producer/survey_data_prep.R',
                length: 4359,
                type: text_plain
              },
              {
                title: 'producer/research_coords.csv',
                length: 5827,
                type: text_csv
              },
              {
                title: 'producer/Laney_300394_Exempt_Determination_Letter.pdf',
                length: 42_686,
                type: application_pdf
              },
              {
                title: 'producer/survey_Q33-37_networking.R',
                length: 22_658,
                type: text_plain
              },
              {
                title: 'producer/SensorSurvey_Printout.pdf',
                length: 1_728_537,
                type: application_pdf
              },
              {
                title: 'producer/survey_Q24_limitsToExpansion.R',
                length: 11_012,
                type: text_plain
              },
              {
                title: 'producer/survey_Q38-42_publications.R',
                length: 1690,
                type: text_plain
              }
            ]

            inventory = wrapper.inventory
            expect(inventory).not_to be_nil

            files = inventory.files
            expect(files.size).to eq(expected.size)

            files.each_with_index do |file, i|
              pathname = expected[i][:title].sub(%r{^producer/}, '')
              size = expected[i][:length]
              type = expected[i][:type]
              expect(file.pathname).to eq(pathname)
              expect(file.size_bytes).to eq(size)
              expect(file.mime_type).to eq(type)
            end
          end

          describe 'license parsing' do

            attr_reader :dcs_resource

            before(:each) do
              datacite_xml = File.read('spec/data/harvester/mrt-datacite.xml')
              @dcs_resource = Datacite::Mapping::Resource.parse_mrt_datacite(datacite_xml, '10.15146/R3RG6G')
              dcs_resource.dates << Datacite::Mapping::Date.new(type: Datacite::Mapping::DateType::AVAILABLE, value: Date.today)
              allow(record).to receive(:build_datacite_resource).and_return(@dcs_resource)
              record.instance_variable_set(:@wrapper, nil)
            end

            it 'extracts a CC0 license' do
              expect(wrapper.license).to eq(Stash::Wrapper::License::CC_ZERO)
            end

            it 'extracts a CC_BY license' do
              rights = dcs_resource.rights_list[0]
              rights.uri = URI('http://creativecommons.org/publicdomain/zero/1.0/')
              rights.value = 'public domain'
              expect(wrapper.license).to eq(Stash::Wrapper::License::CC_ZERO)
            end

            it 'converts "publicdomain" URL to a CC0 license' do
              rights = dcs_resource.rights_list[0]
              rights.uri = URI('https://creativecommons.org/licenses/by/4.0/')
              rights.value = 'Creative Commons Attribution 4.0 International (CC-BY 4.0)'
              expect(wrapper.license).to eq(Stash::Wrapper::License::CC_BY)
            end

            it 'converts a custom license' do
              custom_uri = URI('doi:10.5060/D8PP47')
              custom_value = 'Terms of use are available at: doi:10.5060/D8PP47'
              rights = dcs_resource.rights_list[0]
              rights.uri = custom_uri
              rights.value = custom_value
              license = wrapper.license
              expect(license.name).to eq(custom_value)
              expect(license.uri).to eq(custom_uri)
            end
          end

          describe '#title' do
            it 'extracts the title' do
              expect(record.title).to eq('A Zebrafish Model for Studies on Esophageal Epithelial Biology')
            end
          end

        end

        describe 'EML handling' do
          attr_reader :mrt_eml_uri
          attr_reader :eml_path
          attr_reader :eml_xml
          attr_reader :id_value

          before(:each) do
            @eml_path = 'spec/data/eml/dash1-eml-xml/dataone-ark+=90135=q1bk1994-mrt-eml.xml'
            @eml_xml = File.read(eml_path)

            entry_xml = File.read('spec/data/harvester/eml/entry-q1f769jn.xml')
            @entry = RSS::Parser.parse(entry_xml, false).items[0]
            @record = MerrittAtomHarvestedRecord.new(user_provider, 'example', feed_uri, entry)

            @mrt_mom_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/d/ark:%2F90135%2Fq1f769jn/2/system%2Fmrt-mom.txt"
            stub_request(:get, mrt_mom_uri).to_return(body: File.read('spec/data/harvester/eml/mrt-mom.txt'))

            @id_value = 'ark:/90135/q1f769jn'

            @mrt_eml_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/d/ark:%2F90135%2Fq1f769jn/2/producer%2Fmrt-eml.xml"
            stub_request(:get, mrt_eml_uri).to_return(body: eml_xml)
          end

          it 'returns the EML XML' do
            expect(record.mrt_eml).to eq(eml_xml)
          end

          it 'creates a wrapper' do
            expect(wrapper).to be_a(Stash::Wrapper::StashWrapper)
          end

          it 'converts EML to datacite' do
            resource = wrapper.datacite_resource
            expect(resource).to be_a(Datacite::Mapping::Resource)

            mapped_resource = EmlDataciteMapper.to_datacite(eml_xml, id_value)
            expect(resource.save_to_xml).to be_xml(mapped_resource.save_to_xml)

            puts wrapper.write_xml
          end
        end

      end

    end
  end
end
