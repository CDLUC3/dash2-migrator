require 'spec_helper'

module Dash2
  module Migrator
    module Harvester
      describe StashWrapperBuilder do

        attr_reader :entry
        attr_reader :resource
        attr_reader :builder

        before(:each) do
          entry_xml = File.read('spec/data/harvester/entry-r36p4t.xml')
          @entry = RSS::Parser.parse(entry_xml, false).items[0]

          datacite_xml = File.read('spec/data/harvester/mrt-datacite.xml')
          @resource = Datacite::Mapping::Resource.parse_mrt_datacite(datacite_xml, '10.123/456')
          resource.dates << Datacite::Mapping::Date.new(type: Datacite::Mapping::DateType::AVAILABLE, value: Date.today)

          @builder = StashWrapperBuilder.new(entry: entry, datacite_resource: resource)
        end

        describe 'stash_files' do
          it 'limits the number of files' do
            too_many_files = Array.new(StashWrapperBuilder::MAX_FILES * 2) do |i|
              Stash::Wrapper::StashFile.new(pathname: "file#{i}", size_bytes: i, mime_type: 'text/plain')
            end
            builder.instance_variable_set(:@all_stash_files, too_many_files)
            # builder.instance_variable_set(:@stash_files, nil)
            wrapper = builder.build
            expect(wrapper.stash_files).to eq(too_many_files.take(StashWrapperBuilder::MAX_FILES))
          end
        end

      end
    end
  end
end
