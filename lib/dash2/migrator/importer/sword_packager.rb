require 'stash_engine'
require 'stash/sword'
require 'stash_datacite/dublin_core_builder'
require 'stash_datacite/data_one_manifest_builder'

module Dash2
  module Migrator
    module Importer

      class SwordPackager

        RETRIES = 3

        attr_reader :sword_client
        attr_reader :create_placeholder_files

        def initialize(sword_client:, create_placeholder_files: false)
          @sword_client = SwordPackager.sword_client(sword_client)
          @create_placeholder_files = create_placeholder_files
        end

        def self.sword_client(client)
          return client if client.respond_to?(:create) && client.respond_to?(:update)
          return client if client.to_s =~ /InstanceDouble\(Stash::Sword::Client\)/ # For RSpec tests
          raise ArgumentError, "sword_client does not appear to be a Stash::Sword::Client: #{client || 'nil'}"
        end

        def log
          Stash::Harvester.log
        end

        def submit(stash_wrapper:, dcs_resource:, se_resource:, tenant:)
          package_builder = make_package_builder(dcs_resource, se_resource, stash_wrapper, tenant)
          sword_submit(se_resource, package_builder.make_package)
        end

        def make_package_builder(dcs_resource, se_resource, stash_wrapper, tenant)
          PackageBuilder.new(
            stash_wrapper: stash_wrapper,
            dcs_resource: dcs_resource,
            se_resource: se_resource,
            tenant: tenant,
            create_placeholder_files: create_placeholder_files
          )
        end

        private

        def sword_submit(se_resource, zipfile)
          edit_iri = se_resource.update_uri
          if edit_iri
            submit_update(se_resource, edit_iri, zipfile)
          else
            submit_create(se_resource, zipfile)
          end
          se_resource.set_state('published')
          se_resource.update_version(zipfile)
          se_resource.save
        end

        def submit_create(se_resource, zipfile)
          receipt = SwordCreator.new(
            se_resource: se_resource,
            zipfile: zipfile,
            sword_client: sword_client
          ).submit
          se_resource.download_uri = receipt.em_iri
          se_resource.update_uri = receipt.edit_iri
          id_val = se_resource.identifier.identifier
          Stash::Harvester.log.info("create(doi: #{doi}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) completed with em_iri #{receipt.em_iri}, edit_iri #{receipt.edit_iri}")
        end

        def submit_update(se_resource, edit_iri, zipfile)
          status = SwordUpdater.new(
            se_resource: se_resource,
            edit_iri: edit_iri,
            zipfile: zipfile,
            sword_client: sword_client
          ).submit
          id_val = se_resource.identifier.identifier
          Stash::Harvester.log.info("update(edit_iri: #{edit_iri}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) completed with status #{status}")
        end
      end

      class SwordUpdater

        attr_reader :se_resource
        attr_reader :edit_iri
        attr_reader :zipfile
        attr_reader :sword_client

        def initialize(se_resource:, edit_iri:, zipfile:, sword_client:)
          @se_resource = se_resource
          @edit_iri = edit_iri
          @zipfile = zipfile
          @sword_client = sword_client
        end

        def submit(retries = SwordPackager.RETRIES)
          return sword_client.update(edit_iri: edit_iri, zipfile: zipfile)
        rescue RestClient::Exceptions::ReadTimeout
          return submit(retries - 1) if retries > 0
          raise "Unable to submit #{zipfile} to #{edit_iri}: too many timeouts"
        end
      end

      class SwordCreator
        attr_reader :se_resource
        attr_reader :doi
        attr_reader :zipfile
        attr_reader :sword_client

        def initialize(se_resource:, zipfile:, sword_client:)
          @se_resource = se_resource
          @zipfile = zipfile
          @doi = "doi:#{se_resource.identifier.identifier}"
          @sword_client = sword_client
        end

        def submit(retries = SwordPackager.RETRIES)
          return sword_client.create(doi: doi, zipfile: zipfile)
        rescue RestClient::Exceptions::ReadTimeout
          return submit(retries - 1) if retries > 0
          raise "Unable to submit #{zipfile} for #{doi}: too many timeouts"
        end
      end

      class PackageBuilder
        attr_reader :stash_wrapper
        attr_reader :dcs_resource
        attr_reader :se_resource
        attr_reader :tenant

        def initialize(stash_wrapper:, dcs_resource:, se_resource:, tenant:, create_placeholder_files:)
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

          folder = "#{Dir.tmpdir}/#{time}_import_#{se_resource.id}"
          Dir.mkdir(folder)
          entries = []
          entries << write_mrt_datacite(folder)
          entries << write_stash_wrapper(folder)
          entries << write_mrt_oaidc(folder)
          entries << write_mrt_dataone_manifest(folder)
          entries.concat(placeholder_files_if_any)

          make_zipfile(entries, "#{folder}_archive.zip")
        end

        def make_zipfile(entries, zipfile_path)
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
          stash_wrapper.inventory.files
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
          dc_builder = DublinCoreBuilder.new(resource: se_resource, tenant: tenant)
          File.open(mrt_oaidc_xml, 'w') { |f| f.write(dc_builder.build_xml_string) }
          mrt_oaidc_xml
        end

        def write_mrt_dataone_manifest(folder)
          mrt_dataone_manifest_txt = "#{folder}/mrt-dataone-manifest.txt"
          d1_builder = DataONEManifestBuilder.new(data_files.map { |stash_file| [name: stash_file.pathname, type: stash_file.mime_type.to_s] })
          File.open(mrt_dataone_manifest_txt, 'w') { |f| f.write(d1_builder.build_dataone_manifest) }
          mrt_dataone_manifest_txt
        end

        def placeholder_files_if_any
          return [] unless write_placeholder_files?
          data_files.map do |stash_file|
            data_file = stash_file.pathname
            placeholder_file = "#{folder}/#{data_file}"
            File.open(placeholder_file, 'w') do |f|
              f.puts("#{data_file}\t#{stash_file.size_bytes}\t#{stash_file.mime_type}\t(placeholder)")
            end
            placeholder_file
          end
        end

      end
    end
  end
end
