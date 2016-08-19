require 'tmpdir'
require 'datacite/mapping'
require 'stash_ezid/client'
require 'stash/sword'
require 'dash2/migrator/id_mode'
require 'stash/no_op_persistence_config'

# TODO: Extract all the StashDatacite:: stuff and move it into that module

module Dash2
  module Migrator
    class Importer

      attr_reader :ezid_client
      attr_reader :user_uid
      attr_reader :stash_wrapper
      attr_reader :id_mode
      attr_reader :tenant
      attr_reader :sword_client

      def initialize(stash_wrapper:, user_uid:, ezid_client:, id_mode:, tenant:)
        @stash_wrapper = stash_wrapper
        @user_uid = user_uid
        @ezid_client = ezid_client
        @id_mode = id_mode
        @tenant = tenant
      end

      def import
        user = StashEngine::User.find_by_uid(user_uid)
        raise "No user found for #{user_uid}" unless user

        old_doi = dcs_resource.doi
        migration_record = StashDatacite::AlternateIdentifier.where(
            alternate_identifier: old_doi
        ).take

        if migration_record
          already_migrated_id = migration_record.resource_id
          already_migrated_resource = StashEngine::Resource.where(id: already_migrated_id).take
          already_migrated_doi = already_migrated_resource.identifier.identifier
          Stash::Harvester.log.info("Skipping already migrated DOI #{old_doi} (migrated to #{already_migrated_doi}, resource ID #{already_migrated_id}")
          already_migrated_resource
        else
          se_resource = se_resource_from(dcs_resource: dcs_resource, with_user_id: user.id)
          mint_or_update_doi(se_resource)
          new_doi = se_resource.identifier.identifier
          document_migration(from_doi: old_doi, to_doi: new_doi, se_resource: se_resource)
          stash_wrapper.stash_descriptive[0] = dcs_resource.save_to_xml
          sword_create_or_update(se_resource)
          se_resource
        end
      end

      def mint_or_update_doi(se_resource)
        case id_mode
          when IDMode::ALWAYS_MINT
            mint_new_doi(se_resource)
          when IDMode::ALWAYS_UPDATE
            update_doi(dcs_resource, se_resource)
          else
            raise "Unknown ID mode: #{id_mode || 'nil'}"
        end
      end

      def mint_new_doi(se_resource)
        doi = ezid_client.mint_id
        dcs_resource.identifier = Datacite::Mapping::Identifier.from_doi(doi)
        stash_wrapper.identifier = Stash::Wrapper::Identifier.new(
            type: Stash::Wrapper::IdentifierType::DOI,
            value: dcs_resource.identifier.value
        )
        se_resource.update_identifier(doi)
      end

      def document_migration(from_doi:, to_doi:, se_resource:)
        stash_wrapper.version.note = "Migrated from #{from_doi} to #{to_doi} at #{Time.now.iso8601} in #{ENV['STASH_ENV']}."
        return if ENV['STASH_ENV'] == 'production'

        migration_record = StashDatacite::AlternateIdentifier.create(
            resource_id: se_resource.id,
            alternate_identifier_type: 'migrated from',
            alternate_identifier: from_doi
        )
        migration_record.save

        dcs_resource.alternate_identifiers << Datacite::Mapping::AlternateIdentifier.new(
            type: 'migrated from',
            value: from_doi
        )
      end

      def update_doi(dcs_resource, se_resource)
        doi_value = dcs_resource.identifier.value
        se_resource.update_identifier(doi_value)
        target_url = tenant.landing_url("/stash/dataset/doi:#{doi_value}")
        ezid_client.update_metadata("doi:#{doi_value}", dcs_resource.write_xml, target_url)
      end

      def create_file_uploads(se_resource)
        version_time = stash_wrapper.version.date.to_time
        stash_files = stash_wrapper.inventory.files
        stash_files.each do |sf|
          StashEngine::FileUpload.create(
              resource_id: se_resource.id,
              upload_file_name: sf.pathname,
              upload_content_type: sf.mime_type.to_s,
              upload_file_size: sf.size_bytes,
              upload_updated_at: version_time,
              file_state: 'created'
          )
        end
      end

      def sword_client
        @sword_client ||= Stash::Sword::Client.new(tenant.sword_params)
      end

      def sword_create_or_update(se_resource)
        rfg = StashDatacite::Resource::ResourceFileGeneration.new(se_resource, tenant)
        rfg.instance_variable_set(:@client, ezid_client)

        folder = "#{Dir.tmpdir}/#{Time.now.to_i}_import_#{se_resource.id}"
        Dir.mkdir(folder)

        mrt_datacite_xml = "#{folder}/mrt-datacite.xml"
        dcs_resource.write_to_file(mrt_datacite_xml, pretty: true)

        stash_wrapper_xml = "#{folder}/stash-wrapper.xml"
        stash_wrapper.write_to_file(stash_wrapper_xml, pretty: true)

        mrt_oaidc_xml = "#{folder}/mrt-oaidc.xml"
        File.open(mrt_oaidc_xml, 'w') { |f| f.write(rfg.generate_dublincore) }

        mrt_dataone_manifest_txt = "#{folder}/mrt-dataone-manifest.txt"
        File.open(mrt_dataone_manifest_txt, 'w') { |f| f.write(rfg.generate_dataone) }

        data_files = []
        stash_wrapper.inventory.files.each do |stash_file|
          # Since this is just for test we don't care about zipfile directory structure, we just need valid filenames
          data_file = stash_file.pathname.gsub('/', '-')
          stash_file.pathname = data_file
          File.open("#{folder}/#{data_file}", 'w') do |f|
            f.puts("#{data_file}\t#{stash_file.size_bytes}\t#{stash_file.mime_type}\t(placeholder)")
          end
          data_files << data_file
        end

        zipfile = "#{folder}/#{se_resource.id}_archive.zip"
        Zip::File.open(zipfile, Zip::File::CREATE) do |zf|
          metadata_files = %w(mrt-datacite.xml stash-wrapper.xml mrt-oaidc.xml mrt-dataone-manifest.txt)
          (metadata_files + data_files).each do |f|
            Stash::Harvester.log.info("Adding #{f} to zipfile #{zipfile}")
            zf.add(f, "#{folder}/#{f}")
          end
        end

        edit_iri = se_resource.update_uri
        if edit_iri
          status = sword_client.update(edit_iri: edit_iri, zipfile: zipfile)
          id_val = se_resource.identifier.identifier
          Stash::Harvester.log.info("update(edit_iri: #{edit_iri}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) completed with status #{status}")
        else
          doi = "doi:#{dcs_resource.identifier.value}"

          receipt = nil
          retries = 3
          while receipt.nil? && retries > 0
            begin
              receipt = sword_client.create(doi: doi, zipfile: zipfile)
            rescue RestClient::Exceptions::ReadTimeout => e
              Stash::Harvester.log.warn("ReadTimeout in SWORD submission; #{retries} retries remaining: #{e}")
              retries = retries - 1
            end
          end

          raise "Unable to submit #{doi} to SWORD: too many timeouts" unless receipt

          se_resource.download_uri = receipt.em_iri
          se_resource.update_uri = receipt.edit_iri
          id_val = se_resource.identifier.identifier
          Stash::Harvester.log.info("create(doi: #{doi}, zipfile: #{zipfile}) for resource #{se_resource.id} (#{id_val}) completed with em_iri #{receipt.em_iri}, edit_iri #{receipt.edit_iri}")
        end

        se_resource.set_state('published')
        se_resource.update_version(zipfile)
        se_resource.save

      end

      def dcs_resource
        @dcs_resource ||= begin
          datacite_xml = stash_wrapper.stash_descriptive[0]
          Datacite::Mapping::Resource.parse_xml(datacite_xml)
        end
      end

      def se_resource_from(dcs_resource:, with_user_id:)
        se_resource = make_se_resource(with_user_id)
        populate_se_resource(se_resource, dcs_resource)
        se_resource
      end

      def populate_se_resource(se_resource, dcs_resource)
        create_file_uploads(se_resource)

        se_resource_id = se_resource.id
        dcs_resource.creators.each { |dcs_creator| add_sd_creator(dcs_creator, se_resource_id) }
        dcs_resource.titles.each { |dcs_title| add_sd_title(dcs_title, se_resource_id) }
        set_sd_publisher(dcs_resource.publisher, se_resource_id)
        set_sd_pubyear(dcs_resource.publication_year, se_resource_id)
        dcs_resource.subjects.each { |dcs_subject| add_sd_subject(dcs_subject, se_resource_id) }
        dcs_resource.contributors.each { |dcs_contributor| add_sd_contributor(dcs_contributor, se_resource_id) }
        dcs_resource.dates.each { |dcs_date| add_sd_date(dcs_date, se_resource_id) }
        set_sd_language(dcs_resource.language, se_resource_id)
        set_sd_resource_type(dcs_resource.resource_type, se_resource_id)
        dcs_resource.alternate_identifiers.each { |dcs_alternate_ident| add_sd_alternate_ident(dcs_alternate_ident, se_resource_id) }
        dcs_resource.related_identifiers.each { |dcs_related_ident| add_sd_related_ident(dcs_related_ident, se_resource_id) }
        dcs_resource.sizes.each { |dcs_size| add_sd_size(dcs_size, se_resource_id) }
        dcs_resource.formats.each { |dcs_format| add_sd_format(dcs_format, se_resource_id) }
        set_sd_version(dcs_resource.version, se_resource_id)
        dcs_resource.rights_list.each { |dcs_rights| add_sd_rights(dcs_rights, se_resource_id) }
        dcs_resource.descriptions.each { |dcs_description| add_sd_description(dcs_description, se_resource_id) }
        dcs_resource.geo_locations.each { |dcs_geo_location| add_sd_geo_location(dcs_geo_location, se_resource_id) }
        dcs_resource.funding_references.each { |dcs_funding_reference| add_funding(dcs_funding_reference, se_resource_id) }
        se_resource.geolocation = true unless dcs_resource.geo_locations.empty?
        se_resource.save!
      end

      def make_se_resource(user_id)
        se_resource = StashEngine::Resource.create(user_id: user_id)
        se_resource_state = StashEngine::ResourceState.create(
            user_id: user_id,
            resource_state: 'in_progress',
            resource_id: se_resource.id
        )
        se_resource.update(current_resource_state_id: se_resource_state.id)
        se_resource
      end

      def add_sd_creator(dcs_creator, se_resource_id)
        last_name, first_name = extract_last_first(dcs_creator.name)
        sd_creator = StashDatacite::Creator.create(
            creator_first_name: first_name,
            creator_last_name: last_name,
            name_identifier_id: sd_name_identifier_id_for(dcs_creator.identifier),
            resource_id: se_resource_id
        )
        sd_creator.affiliation_ids = dcs_creator.affiliations.map { |affiliation_str| sd_affiliation_id_for(affiliation_str) }
        sd_creator
      end

      def add_sd_title(dcs_title, se_resource_id)
        title_type = dcs_title.type
        StashDatacite::Title.create(
            title: dcs_title.value,
            title_type_friendly: (title_type.value if title_type),
            resource_id: se_resource_id
        )
      end

      def set_sd_publisher(dcs_publisher, se_resource_id)
        unless dcs_publisher.blank?
          StashDatacite::Publisher.create(publisher: dcs_publisher, resource_id: se_resource_id)
        end
      end

      def set_sd_pubyear(dcs_publication_year, se_resource_id)
        return if dcs_publication_year.blank?
        StashDatacite::PublicationYear.create(publication_year: dcs_publication_year, resource_id: se_resource_id)
      end

      def add_sd_subject(dcs_subject, se_resource_id)
        sd_subject_id = sd_subject_id_for(dcs_subject)
        StashDatacite::ResourcesSubjects.create(resource_id: se_resource_id, subject_id: sd_subject_id)
      end

      def add_sd_contributor(dcs_contributor, se_resource_id)
        contributor_type = dcs_contributor.type
        sd_contributor = StashDatacite::Contributor.create(
            contributor_name: dcs_contributor.name,
            contributor_type_friendly: (contributor_type.value if contributor_type),
            name_identifier_id: sd_name_identifier_id_for(dcs_contributor.identifier),
            resource_id: se_resource_id
        )
        sd_contributor.affiliation_ids = dcs_contributor.affiliations.map { |affiliation_str| sd_affiliation_id_for(affiliation_str) }
        sd_contributor
      end

      def add_sd_date(dcs_date, se_resource_id)
        date_type = dcs_date.type
        StashDatacite::DataciteDate.create(
            date: dcs_date.value,
            date_type_friendly: (date_type.value if date_type),
            resource_id: se_resource_id
        )
      end

      def set_sd_language(dcs_language, se_resource_id)
        return nil if dcs_language.blank?
        StashDatacite::Language.create(language: dcs_language, resource_id: se_resource_id)
      end

      def set_sd_resource_type(dcs_resource_type, se_resource_id)
        return nil unless dcs_resource_type
        dcs_resource_type_general = dcs_resource_type.resource_type_general
        se_resource_type = dcs_resource_type_general.value.downcase
        StashDatacite::ResourceType.create(
            resource_id: se_resource_id,
            resource_type_friendly: if StashDatacite::ResourceType::ResourceTypesLimited.values.include?(se_resource_type) then
                                      se_resource_type
                                    else
                                      'other'
                                    end
        )
      end

      def add_sd_alternate_ident(dcs_alternate_ident, se_resource_id)
        StashDatacite::AlternateIdentifier.create(
            alternate_identifier: dcs_alternate_ident.value,
            alternate_identifier_type: dcs_alternate_ident.type, # a string, not an enum
            resource_id: se_resource_id
        )
      end

      def add_sd_related_ident(dcs_related_ident, se_resource_id)
        ident_type = dcs_related_ident.identifier_type
        rel_type = dcs_related_ident.relation_type
        scheme_uri = dcs_related_ident.scheme_uri
        StashDatacite::RelatedIdentifier.create(
            related_identifier: dcs_related_ident.value,
            related_identifier_type_friendly: (ident_type.value if ident_type),
            relation_type_friendly: (rel_type.value if rel_type),
            related_metadata_scheme: dcs_related_ident.related_metadata_scheme,
            scheme_URI: (scheme_uri.to_s if scheme_uri),
            scheme_type: dcs_related_ident.scheme_type,
            resource_id: se_resource_id
        )
      end

      def add_sd_size(dcs_size, se_resource_id)
        return if dcs_size.blank?
        StashDatacite::Size.create(size: dcs_size, resource_id: se_resource_id)
      end

      def add_sd_format(dcs_format, se_resource_id)
        return if dcs_format.blank?
        StashDatacite::Format.create(format: dcs_format, resource_id: se_resource_id)
      end

      def set_sd_version(dcs_version, se_resource_id)
        return if dcs_version.blank?
        StashDatacite::Version.create(version: dcs_version, resource_id: se_resource_id)
      end

      def add_sd_rights(dcs_rights, se_resource_id)
        rights_uri = dcs_rights.uri
        StashDatacite::Right.create(
            rights: dcs_rights.value,
            rights_uri: (rights_uri.to_s if rights_uri),
            resource_id: se_resource_id
        )
      end

      def add_sd_description(dcs_description, se_resource_id)
        return if dcs_description.funding?
        desc_type = dcs_description.type
        StashDatacite::Description.create(
            description: dcs_description.value,
            description_type_friendly: (desc_type.value if desc_type),
            resource_id: se_resource_id
        )
      end

      def add_sd_geo_location(dcs_geo_location, se_resource_id)
        add_sd_geo_location_place(dcs_geo_location.place, se_resource_id)
        add_sd_geo_location_point(dcs_geo_location.point, se_resource_id)
        add_sd_geo_location_box(dcs_geo_location.box, se_resource_id)
      end

      def add_sd_geo_location_place(dcs_geo_location_place, se_resource_id)
        return if dcs_geo_location_place.blank?
        StashDatacite::GeolocationPlace.create(geo_location_place: dcs_geo_location_place, resource_id: se_resource_id)
      end

      def add_sd_geo_location_point(dcs_geo_location_point, se_resource_id)
        return unless dcs_geo_location_point
        StashDatacite::GeolocationPoint.create(
            latitude: dcs_geo_location_point.latitude,
            longitude: dcs_geo_location_point.longitude,
            resource_id: se_resource_id
        )
      end

      def add_sd_geo_location_box(dcs_geo_location_box, se_resource_id)
        return unless dcs_geo_location_box
        StashDatacite::GeolocationBox.create(
            sw_latitude: dcs_geo_location_box.south_latitude,
            sw_longitude: dcs_geo_location_box.west_longitude,
            ne_latitude: dcs_geo_location_box.north_latitude,
            ne_longitude: dcs_geo_location_box.east_longitude,
            resource_id: se_resource_id
        )
      end

      def add_funding(dcs_funding_reference, se_resource_id)
        award_number = dcs_funding_reference.award_number
        StashDatacite::Contributor.create(
            contributor_name: dcs_funding_reference.name,
            contributor_type: Datacite::Mapping::ContributorType::FUNDER.value.downcase,
            award_number: (award_number.value if award_number),
            resource_id: se_resource_id
        )
      end

      private

      def extract_last_first(name_w_comma)
        name_w_comma.split(',', 2).map(&:strip)
      end

      def sd_affiliation_id_for(affiliation_str)
        sd_affiliations = StashDatacite::Affiliation.where('short_name = ? or long_name = ?', affiliation_str, affiliation_str)
        return sd_affiliations.first.id unless sd_affiliations.empty?
        StashDatacite::Affiliation.create(long_name: affiliation_str).id unless affiliation_str.blank?
      end

      def sd_name_identifier_id_for(dcs_name_identifier)
        return nil unless dcs_name_identifier
        scheme_uri = dcs_name_identifier.scheme_uri
        sd_name_ident = StashDatacite::NameIdentifier.find_or_create_by(
            name_identifier: dcs_name_identifier.value,
            name_identifier_scheme: dcs_name_identifier.scheme,
            scheme_URI: (scheme_uri if scheme_uri)
        )
        sd_name_ident.id
      end

      def sd_subject_id_for(dcs_subject)
        return nil unless dcs_subject
        scheme_uri = dcs_subject.scheme_uri
        StashDatacite::Subject.find_or_create_by(
            subject: dcs_subject.value,
            subject_scheme: dcs_subject.scheme,
            scheme_URI: (scheme_uri if scheme_uri)
        ).id
      end

    end
  end
end
