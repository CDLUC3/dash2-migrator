require 'spec_helper'

RSpec::Matchers.define :be_resource do |expected|
  match do |actual|
    return actual.nil? unless expected
    raise "Expected value #{expected} is not a Datacite::Mapping::Resource" unless expected.is_a?(Datacite::Mapping::Resource)
    raise "Actual value #{actual} is not a Datacite::Mapping::Resource" unless actual.is_a?(Datacite::Mapping::Resource)
    expected_xml = expected.write_xml
    actual_xml = actual.write_xml
    Stash::XMLMatchUtils.equivalent?(expected_xml, actual_xml)
  end

  failure_message do |actual|
    Stash::XMLMatchUtils.failure_message(expected.write_xml, actual.write_xml).sub('expected XML', 'expected Resource')
  end

end

module Stash
  module Wrapper
    describe StashWrapper do
      attr_reader :wrapper
      attr_reader :resource

      before(:each) do
        wrapper_xml = File.read('spec/data/harvested-wrapper.xml')
        @wrapper = StashWrapper.parse_xml(wrapper_xml)
        datacite_xml = File.read('spec/data/harvested-datacite.xml')
        @resource = Datacite::Mapping::Resource.parse_xml(datacite_xml)
      end

      describe '#datacite_resource' do
        it 'extracts the resource' do
          expect(wrapper.datacite_resource).to be_resource(resource)
        end
      end

      describe '#datacite_resource=' do
        it 'sets the descriptive element' do
          new_description_value = 'Help I am trapped in a metadata factory'
          resource.descriptions << Datacite::Mapping::Description.new(
            type: Datacite::Mapping::DescriptionType::OTHER,
            value: new_description_value
          )
          wrapper.datacite_resource = resource

          descriptive = wrapper.stash_descriptive[0]
          expect(descriptive).to be_a(REXML::Element)
          expect(descriptive.to_s).to match(new_description_value)
          expect(wrapper.datacite_resource).to be_resource(resource)
        end
      end

      describe '#stash_files' do
        it 'returns the files' do
          expect(wrapper.stash_files).to be(wrapper.inventory.files)
        end
      end

      describe '#version_date' do
        it 'returns the date' do
          expect(wrapper.version_date).to be(wrapper.version.date)
        end
      end
    end
  end
end
