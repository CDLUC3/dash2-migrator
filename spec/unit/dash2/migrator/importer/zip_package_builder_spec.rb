require 'spec_helper'

module Dash2
  module Migrator
    module Importer
      describe ZipPackageBuilder do

        attr_reader :wrapper_xml
        attr_reader :datacite_xml

        attr_reader :stash_wrapper
        attr_reader :dcs_resource
        attr_reader :se_resource
        attr_reader :tenant

        attr_reader :zipfile_path

        def zipfile
          @zipfile ||= ::Zip::File.open(zipfile_path)
        end

        def zip_entry(path)
          @zip_entries ||= {}
          @zip_entries[path] ||= begin
            entry = zipfile.find_entry(path)
            entry_io = entry.get_input_stream
            entry_io.read
          end
        end

        before(:each) do
          @wrapper_xml = File.read('spec/data/harvested-wrapper.xml')
          @datacite_xml = File.read('spec/data/harvested-datacite.xml')

          @stash_wrapper = Stash::Wrapper::StashWrapper.parse_xml(wrapper_xml)
          @dcs_resource = Datacite::Mapping::Resource.parse_xml(datacite_xml)

          @tenant = double(StashEngine::Tenant)
          allow(tenant).to receive(:long_name).and_return('University of California, San Francisco')

          @se_resource = double(StashEngine::Resource)

          allow(se_resource).to receive(:id).and_return(17)

          allow(se_resource).to receive(:creators).and_return(dcs_resource.creators.map do |c|
            creator = double(StashDatacite::Creator)
            allow(creator).to receive(:creator_full_name).and_return(c.name)
            creator
          end)

          allow(se_resource).to receive(:contributors).and_return(dcs_resource.contributors.map do |c|
            contrib = double(StashDatacite::Contributor)
            allow(contrib).to receive(:contributor_name).and_return(c.name)
            allow(contrib).to receive(:award_number).and_return(nil)
            contrib
          end)

          titles_relation = double(ActiveRecord::Relation)
          titles = dcs_resource.titles.select { |t| t.type.nil? }.map do |t|
            title = double(StashDatacite::Title)
            allow(title).to receive(:title).and_return(t.value)
            title
          end
          allow(titles_relation).to receive(:where).with(title_type: nil).and_return(titles)
          allow(se_resource).to receive(:titles).and_return(titles_relation)

          pub_year = double(StashDatacite::PublicationYear)
          allow(pub_year).to receive(:publication_year).and_return(dcs_resource.publication_year)
          allow(se_resource).to receive(:publication_years).and_return([pub_year])

          allow(se_resource).to receive(:subjects).and_return(dcs_resource.subjects.map {|s|
            subject = double(StashDatacite::Subject)
            allow(subject).to receive(:subject).and_return(s.value)
            subject
          })

          resource_type = double(StashDatacite::ResourceType)
          allow(resource_type).to receive(:resource_type).and_return(dcs_resource.type.downcase)
          allow(se_resource).to receive(:resource_type).and_return(resource_type)

          allow(se_resource).to receive(:rights).and_return(dcs_resource.rights_list.map {|r|
            rights = double(StashDatacite::Right)
            allow(rights).to receive(:rights).and_return(r.value)
            allow(rights).to receive(:rights_uri).and_return(r.uri.to_s)
            rights
          })

          allow(se_resource).to receive(:descriptions).and_return(dcs_resource.descriptions.map {|d|
            desc = double(StashDatacite::Description)
            allow(desc).to receive(:description).and_return(d.value)
            desc
          })

          allow(se_resource).to receive(:related_identifiers).and_return(dcs_resource.related_identifiers.map {|rid|
            ident = double(StashDatacite::RelatedIdentifier)
            allow(ident).to receive(:relation_type_friendly).and_return(rid.relation_type.value)
            allow(ident).to receive(:related_identifier_type_friendly).and_return(rid.identifier_type.value)
            allow(ident).to receive(:related_identifier).and_return(rid.value)
            ident
          })

          zp_builder = ZipPackageBuilder.new(
            stash_wrapper: stash_wrapper,
            dcs_resource: dcs_resource,
            se_resource: se_resource,
            tenant: tenant
          )
          @zipfile_path = zp_builder.make_package
        end

        it 'writes metadata files' do
          expected_metadata = {
            'mrt-datacite.xml' => datacite_xml,
            'stash-wrapper.xml' => wrapper_xml,
            'mrt-oaidc.xml' => File.read('spec/data/generated-oaidc.xml'),
            'mrt-dataone-manifest.txt' => File.read('spec/data/generated-dataone-manifest.txt')
          }
          expect(zipfile.size).to eq(expected_metadata.size)
          expected_metadata.each do |path, content|
            if path.end_with?('xml')
              expect(zip_entry(path)).to be_xml(content)
            else
              expect(zip_entry(path)).to eq(content)
            end
          end
        end

        describe 'placeholder files' do
          before(:each) do
            zp_builder = ZipPackageBuilder.new(
              stash_wrapper: stash_wrapper,
              dcs_resource: dcs_resource,
              se_resource: se_resource,
              tenant: tenant,
              create_placeholder_files: true
            )
            @zipfile_path = zp_builder.make_package
          end
        end

        describe 'deep paths' do
          it 'writes datafiles with deep directory paths'
        end
      end
    end
  end
end
