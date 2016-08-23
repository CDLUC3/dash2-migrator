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

        def initialize(sword_client:)
          @sword_client = SwordPackager.sword_client(sword_client)
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
          package_builder = PackageBuilder.new(
            stash_wrapper: stash_wrapper,
            dcs_resource: dcs_resource,
            se_resource: se_resource,
            tenant: tenant
          )
          sword_submit(se_resource, package_builder.make_package)
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

        def initialize(stash_wrapper:, dcs_resource:, se_resource:, tenant:)
          @stash_wrapper = stash_wrapper
          @dcs_resource = dcs_resource
          @se_resource = se_resource
          @tenant = tenant
        end

        def make_package
          time = Time.now.to_i

          folder = "#{Dir.tmpdir}/#{time}_import_#{se_resource.id}"
          Dir.mkdir(folder)
          entries = []
          package_dcs_resource(folder, entries)
          package_stash_wrapper(folder, entries)
          package_se_resource(folder, entries)
          package_data_files(folder, entries)

          make_zipfile(entries, "#{folder}/#{time}_import_#{se_resource.id}_archive.zip")
        end

        def make_zipfile(entries, zipfile_path)
          Zip::File.open(zipfile_path, Zip::File::CREATE) do |zf|
            entries.each do |full_path|
              filename = full_path.split('/')[-1]
              zf.add(filename, full_path)
            end
          end
          zipfile_path
        end

        def data_files
          stash_wrapper.inventory.files
        end

        def package_dcs_resource(folder, entries)
          mrt_datacite_xml = "#{folder}/mrt-datacite.xml"
          dcs_resource.write_to_file(mrt_datacite_xml, pretty: true)
          entries < mrt_datacite_xml
        end

        def package_stash_wrapper(folder, entries)
          stash_wrapper_xml = "#{folder}/stash-wrapper.xml"
          stash_wrapper.write_to_file(stash_wrapper_xml, pretty: true)
          entries < stash_wrapper_xml
        end

        def package_se_resource(folder, entries)
          mrt_oaidc_xml = "#{folder}/mrt-oaidc.xml"
          dc_builder = DublinCoreBuilder.new(resource: se_resource, tenant: tenant)
          File.open(mrt_oaidc_xml, 'w') { |f| f.write(dc_builder.build_xml_string) }
          entries < mrt_oaidc_xml
        end

        def package_data_files(folder, entries)
          mrt_dataone_manifest_txt = "#{folder}/mrt-dataone-manifest.txt"
          d1_builder = DataONEManifestBuilder.new(data_files.map { |stash_file| [name: stash_file.pathname, type: stash_file.mime_type.to_s] })
          File.open(mrt_dataone_manifest_txt, 'w') { |f| f.write(d1_builder.build_dataone_manifest) }
          entries << mrt_dataone_manifest_txt
        end

      end
    end
  end
end
