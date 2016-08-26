require 'stash/wrapper'
require 'datacite/mapping'
require 'stash_engine'
require 'stash_datacite/dublin_core_builder'
require 'stash_datacite/data_one_manifest_builder'
require 'tmpdir'
require 'fileutils'

module Dash2
  module Migrator
    module Importer
      class ZipPackageBuilder
        attr_reader :stash_wrapper
        attr_reader :dcs_resource
        attr_reader :se_resource
        attr_reader :tenant

        def initialize(stash_wrapper:, dcs_resource:, se_resource:, tenant:, create_placeholder_files: false)
          @stash_wrapper = stash_wrapper
          @dcs_resource = dcs_resource
          @se_resource = se_resource
          @tenant = tenant
          @create_placeholder_files = create_placeholder_files
        end

        def create_placeholder_files?
          @create_placeholder_files
        end

        def make_package # rubocop:disable Metrics/AbcSize
          time = Time.now.to_i

          folder = Dir.mktmpdir("#{time}_import_#{se_resource.id}")
          entries = []
          entries << write_mrt_datacite(folder)
          entries << write_stash_wrapper(folder)
          entries << write_mrt_oaidc(folder)
          entries << write_mrt_dataone_manifest(folder)
          entries.concat(placeholder_files_if_any(folder))

          make_zipfile(folder, entries)
        end

        def make_zipfile(folder, entries)
          zipfile_path = "#{folder}/archive.zip"
          Zip::File.open(zipfile_path, Zip::File::CREATE) do |zf|
            # TODO: test deep paths
            entries.each do |full_path|
              filename = full_path.sub("#{folder}/", '')
              zf.add(filename, full_path)
            end
          end
          zipfile_path
        end

        def data_files
          stash_wrapper.stash_files
        end

        def data_file_hash
          data_files.map do |stash_file|
            {
              name: stash_file.pathname,
              type: stash_file.mime_type.to_s
            }
          end
        end

        def write_mrt_datacite(folder)
          mrt_datacite_xml = "#{folder}/mrt-datacite.xml"
          dcs_resource.write_to_file(mrt_datacite_xml, pretty: true)
          mrt_datacite_xml
        end

        def write_stash_wrapper(folder)
          stash_wrapper_xml = "#{folder}/stash-wrapper.xml"
          stash_wrapper.write_to_file(stash_wrapper_xml, pretty: true)
          stash_wrapper_xml
        end

        def write_mrt_oaidc(folder)
          mrt_oaidc_xml = "#{folder}/mrt-oaidc.xml"
          dc_builder = StashDatacite::Resource::DublinCoreBuilder.new(resource: se_resource, tenant: tenant)
          File.open(mrt_oaidc_xml, 'w') { |f| f.write(dc_builder.build_xml_string) }
          mrt_oaidc_xml
        end

        def write_mrt_dataone_manifest(folder)
          mrt_dataone_manifest_txt = "#{folder}/mrt-dataone-manifest.txt"
          d1_builder = StashDatacite::Resource::DataONEManifestBuilder.new(data_file_hash)
          File.open(mrt_dataone_manifest_txt, 'w') { |f| f.write(d1_builder.build_dataone_manifest) }
          mrt_dataone_manifest_txt
        end

        def placeholder_files_if_any(folder)
          return [] unless create_placeholder_files?
          data_files.map do |stash_file|
            data_file = stash_file.pathname
            placeholder_file = "#{folder}/#{data_file}"
            maybe_mkdir(placeholder_file)
            File.open(placeholder_file, 'w') do |f|
              f.puts("#{data_file}\t#{stash_file.size_bytes}\t#{stash_file.mime_type}\t(placeholder)")
            end
            placeholder_file
          end
        end

        def maybe_mkdir(placeholder_file)
          parent = File.dirname(placeholder_file)
          FileUtils.mkdir_p(parent) unless File.directory?(parent)
        end

      end
    end
  end
end
