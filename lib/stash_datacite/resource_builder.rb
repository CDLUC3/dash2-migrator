require 'stash_datacite'
require 'stash_engine'
require 'datacite/mapping'
require 'stash/wrapper'
require 'time'

module StashDatacite
  class ResourceBuilder

    attr_reader :user_id
    attr_reader :dcs_resource
    attr_reader :stash_files
    attr_reader :upload_time

    def initialize(user_id:, dcs_resource:, stash_files:, upload_date:)
      @user_id = user_id
      @dcs_resource = ResourceBuilder.dcs_resource(dcs_resource)
      @stash_files = ResourceBuilder.stash_files(stash_files)
      @upload_time = upload_date.to_time
    end

    def self.dcs_resource(dcs_resource)
      return dcs_resource if dcs_resource.is_a?(Datacite::Mapping::Resource)
      return dcs_resource if dcs_resource.to_s =~ /InstanceDouble\(Datacite::Mapping::Resource\)/ # For RSpec tests
      raise ArgumentError, "dcs_resource does not appear to be a Datacite::Mapping::Resource: #{dcs_resource || 'nil'}"
    end

    def self.stash_files(stash_files)
      return stash_files if stash_files.all? do |file|
        file.is_a?(Stash::Wrapper::StashFile) ||
          file.to_s =~ /InstanceDouble\(Stash::Wrapper::StashFile\)/ # For RSpec tests
      end
      raise ArgumentError, "stash_files does not appear to be an array of Stash::Wrapper::StashFile objects: #{stash_files || 'nil'}"
    end

    def build
      populate_se_resource!
    end

    private

    def se_resource
      @se_resource ||= begin
        se_resource = StashEngine::Resource.create(user_id: user_id)
        se_resource_state = StashEngine::ResourceState.create(
          user_id: user_id,
          resource_state: 'in_progress',
          resource_id: se_resource.id
        )
        se_resource.update(current_resource_state_id: se_resource_state.id)
        se_resource
      end
    end
    
    def se_resource_id
      se_resource.id
    end

    def populate_se_resource!
      stash_files.each { |stash_file| add_stash_file(stash_file) }
      dcs_resource.creators.each { |dcs_creator| add_sd_creator(dcs_creator) }
      dcs_resource.titles.each { |dcs_title| add_sd_title(dcs_title) }
      set_sd_publisher(dcs_resource.publisher)
      set_sd_pubyear(dcs_resource.publication_year)
      dcs_resource.subjects.each { |dcs_subject| add_sd_subject(dcs_subject) }
      dcs_resource.contributors.each { |dcs_contributor| add_sd_contributor(dcs_contributor) }
      dcs_resource.dates.each { |dcs_date| add_sd_date(dcs_date) }
      set_sd_language(dcs_resource.language)
      set_sd_resource_type(dcs_resource.resource_type)
      dcs_resource.alternate_identifiers.each { |dcs_alternate_ident| add_sd_alternate_ident(dcs_alternate_ident) }
      dcs_resource.related_identifiers.each { |dcs_related_ident| add_sd_related_ident(dcs_related_ident) }
      dcs_resource.sizes.each { |dcs_size| add_sd_size(dcs_size) }
      dcs_resource.formats.each { |dcs_format| add_sd_format(dcs_format) }
      set_sd_version(dcs_resource.version)
      dcs_resource.rights_list.each { |dcs_rights| add_sd_rights(dcs_rights) }
      dcs_resource.descriptions.each { |dcs_description| add_sd_description(dcs_description) }
      dcs_resource.geo_locations.each { |dcs_geo_location| add_sd_geo_location(dcs_geo_location) }
      dcs_resource.funding_references.each { |dcs_funding_reference| add_funding(dcs_funding_reference) }
      se_resource.geolocation = true unless dcs_resource.geo_locations.empty?
      se_resource.save!
      se_resource
    end
    
    def add_stash_file(stash_file)
      StashEngine::FileUpload.create(
        resource_id: se_resource_id,
        upload_file_name: stash_file.pathname,
        upload_content_type: stash_file.mime_type.to_s,
        upload_file_size: stash_file.size_bytes,
        upload_updated_at: upload_time,
        file_state: 'created'
      )
    end

    def add_sd_creator(dcs_creator)
      last_name, first_name = extract_last_first(dcs_creator.name)
      sd_creator = Creator.create(
        creator_first_name: first_name,
        creator_last_name: last_name,
        name_identifier_id: sd_name_identifier_id_for(dcs_creator.identifier),
        resource_id: se_resource_id
      )
      sd_creator.affiliation_ids = dcs_creator.affiliations.map { |affiliation_str| sd_affiliation_id_for(affiliation_str) }
      sd_creator
    end

    def add_sd_title(dcs_title)
      title_type = dcs_title.type
      Title.create(
        title: dcs_title.value,
        title_type_friendly: (title_type.value if title_type),
        resource_id: se_resource_id
      )
    end

    def set_sd_publisher(dcs_publisher)
      unless dcs_publisher.blank?
        Publisher.create(publisher: dcs_publisher, resource_id: se_resource_id)
      end
    end

    def set_sd_pubyear(dcs_publication_year)
      return if dcs_publication_year.blank?
      PublicationYear.create(publication_year: dcs_publication_year, resource_id: se_resource_id)
    end

    def add_sd_subject(dcs_subject)
      sd_subject_id = sd_subject_id_for(dcs_subject)
      ResourcesSubjects.create(resource_id: se_resource_id, subject_id: sd_subject_id)
    end

    def add_sd_contributor(dcs_contributor)
      contributor_type = dcs_contributor.type
      sd_contributor = Contributor.create(
        contributor_name: dcs_contributor.name,
        contributor_type_friendly: (contributor_type.value if contributor_type),
        name_identifier_id: sd_name_identifier_id_for(dcs_contributor.identifier),
        resource_id: se_resource_id
      )
      sd_contributor.affiliation_ids = dcs_contributor.affiliations.map { |affiliation_str| sd_affiliation_id_for(affiliation_str) }
      sd_contributor
    end

    def add_sd_date(dcs_date)
      date_type = dcs_date.type
      DataciteDate.create(
        date: dcs_date.value,
        date_type_friendly: (date_type.value if date_type),
        resource_id: se_resource_id
      )
    end

    def set_sd_language(dcs_language)
      return nil if dcs_language.blank?
      Language.create(language: dcs_language, resource_id: se_resource_id)
    end

    def set_sd_resource_type(dcs_resource_type)
      return nil unless dcs_resource_type
      dcs_resource_type_general = dcs_resource_type.resource_type_general
      se_resource_type = dcs_resource_type_general.value.downcase
      ResourceType.create(
        resource_id: se_resource_id,
        resource_type_friendly: if ResourceType::ResourceTypesLimited.values.include?(se_resource_type) then
                                  se_resource_type
                                else
                                  'other'
                                end
      )
    end

    def add_sd_alternate_ident(dcs_alternate_ident)
      AlternateIdentifier.create(
        alternate_identifier: dcs_alternate_ident.value,
        alternate_identifier_type: dcs_alternate_ident.type, # a string, not an enum
        resource_id: se_resource_id
      )
    end

    def add_sd_related_ident(dcs_related_ident)
      ident_type = dcs_related_ident.identifier_type
      rel_type = dcs_related_ident.relation_type
      scheme_uri = dcs_related_ident.scheme_uri
      RelatedIdentifier.create(
        related_identifier: dcs_related_ident.value,
        related_identifier_type_friendly: (ident_type.value if ident_type),
        relation_type_friendly: (rel_type.value if rel_type),
        related_metadata_scheme: dcs_related_ident.related_metadata_scheme,
        scheme_URI: (scheme_uri.to_s if scheme_uri),
        scheme_type: dcs_related_ident.scheme_type,
        resource_id: se_resource_id
      )
    end

    def add_sd_size(dcs_size)
      return if dcs_size.blank?
      Size.create(size: dcs_size, resource_id: se_resource_id)
    end

    def add_sd_format(dcs_format)
      return if dcs_format.blank?
      Format.create(format: dcs_format, resource_id: se_resource_id)
    end

    def set_sd_version(dcs_version)
      return if dcs_version.blank?
      Version.create(version: dcs_version, resource_id: se_resource_id)
    end

    def add_sd_rights(dcs_rights)
      rights_uri = dcs_rights.uri
      Right.create(
        rights: dcs_rights.value,
        rights_uri: (rights_uri.to_s if rights_uri),
        resource_id: se_resource_id
      )
    end

    def add_sd_description(dcs_description)
      return if dcs_description.funding?
      desc_type = dcs_description.type
      Description.create(
        description: dcs_description.value,
        description_type_friendly: (desc_type.value if desc_type),
        resource_id: se_resource_id
      )
    end

    def add_sd_geo_location(dcs_geo_location)
      add_sd_geo_location_place(dcs_geo_location.place)
      add_sd_geo_location_point(dcs_geo_location.point)
      add_sd_geo_location_box(dcs_geo_location.box)
    end

    def add_sd_geo_location_place(dcs_geo_location_place)
      return if dcs_geo_location_place.blank?
      GeolocationPlace.create(geo_location_place: dcs_geo_location_place, resource_id: se_resource_id)
    end

    def add_sd_geo_location_point(dcs_geo_location_point)
      return unless dcs_geo_location_point
      GeolocationPoint.create(
        latitude: dcs_geo_location_point.latitude,
        longitude: dcs_geo_location_point.longitude,
        resource_id: se_resource_id
      )
    end

    def add_sd_geo_location_box(dcs_geo_location_box)
      return unless dcs_geo_location_box
      GeolocationBox.create(
        sw_latitude: dcs_geo_location_box.south_latitude,
        sw_longitude: dcs_geo_location_box.west_longitude,
        ne_latitude: dcs_geo_location_box.north_latitude,
        ne_longitude: dcs_geo_location_box.east_longitude,
        resource_id: se_resource_id
      )
    end

    def add_funding(dcs_funding_reference)
      award_number = dcs_funding_reference.award_number
      Contributor.create(
        contributor_name: dcs_funding_reference.name,
        contributor_type: Datacite::Mapping::ContributorType::FUNDER.value.downcase,
        award_number: (award_number.value if award_number),
        resource_id: se_resource_id
      )
    end

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
