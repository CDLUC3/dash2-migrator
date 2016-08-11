require 'spec_helper'

require 'webmock/rspec'

module Dash2
  module Migrator
    describe 'MerrittAtomHarvestedRecord' do
      attr_reader :record
      attr_reader :wrapper

      before(:all) do
        WebMock.disable_net_connect!
      end

      before(:each) do
        base_feed_uri = 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd'
        tenant_path = File.absolute_path('config/tenants/dataone.yml')
        config = MerrittAtomSourceConfig.new(tenant_path: tenant_path, feed_uri: base_feed_uri, env_name: 'test')

        mrt_mom_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr36p4t/2/system%2Fmrt-mom.txt"
        stub_request(:get, mrt_mom_uri).to_return(body: File.read('spec/data/mrt-mom.txt'))

        datacite_uri = "https://#{config.username}:#{config.password}@merritt.cdlib.org/d/ark%3A%2Fc5146%2Fr36p4t/2/producer%2Fmrt-datacite.xml"
        stub_request(:get, datacite_uri).to_return(body: File.read('spec/data/mrt-datacite.xml'))

        feed_uri = config.feed_uri
        entry_xml = File.read('spec/data/entry-r36p4t.xml')
        entry = RSS::Parser.parse(entry_xml, false).items[0]
        @record = MerrittAtomHarvestedRecord.new(feed_uri, entry)
        @wrapper = record.as_wrapper
      end

      describe '#identifier' do
        it 'extracts the identifier' do
          expect(record.identifier).to eq('http://n2t.net/ark:/c5146/r36p4t')
        end
      end

      describe '#stash_wrapper' do
        it 'creates a StashWrapper' do
          expect(wrapper).to be_a(Stash::Wrapper::StashWrapper)
          # File.open('tmp/harvested-wrapper.xml', 'w') do |f|
          #   f.write(wrapper.write_xml)
          # end
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
            pathname = expected[i][:title].sub(/^producer\//, '')
            size = expected[i][:length]
            type = expected[i][:type]
            expect(file.pathname).to eq(pathname)
            expect(file.size_bytes).to eq(size)
            expect(file.mime_type).to eq(type)
          end
        end

        it 'extracts the license' do
          expect(wrapper.license).to eq(Stash::Wrapper::License::CC_ZERO)
        end
      end
    end
  end
end