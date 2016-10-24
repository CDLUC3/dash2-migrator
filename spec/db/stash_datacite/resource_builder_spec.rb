require 'db_spec_helper'

module StashDatacite
  describe ResourceBuilder do

    attr_reader :wrapper
    attr_reader :dcs_resource
    attr_reader :stash_files
    attr_reader :se_resource

    before(:all) do
      @user_uid = 'lmuckenhaupt-ucop@ucop.edu'
    end

    before(:each) do
      wrapper_xml = File.read('spec/data/harvested-wrapper.xml')
      # TODO: remove gsubs
      @wrapper = Stash::Wrapper::StashWrapper.parse_xml(wrapper_xml.gsub(/-\s+/, '').gsub(/\s+/, ' '))
      @stash_files = wrapper.stash_files

      datacite_xml = wrapper.stash_descriptive[0]
      @dcs_resource = Datacite::Mapping::Resource.parse_xml(datacite_xml)

      user_uid = 'lmuckenhaupt-ucop@ucop.edu'
      user_id = StashEngine::User.create(
        uid: user_uid,
        first_name: 'Lisa',
        last_name: 'Muckenhaupt',
        email: 'lmuckenhaupt@ucop.org',
        provider: 'developer',
        tenant_id: 'ucop'
      ).id

      builder = ResourceBuilder.new(
        user_id: user_id,
        dcs_resource: dcs_resource,
        stash_files: stash_files,
        upload_date: wrapper.version_date
      )
      @se_resource = builder.build
    end

    it 'creates a StashEngine::Resource' do
      expect(se_resource).to be_a(StashEngine::Resource)
    end

    it 'sets the identifier' do
      se_ident = se_resource.identifier
      expect(se_ident).not_to be_nil
      expect(se_ident.identifier_type).to eq('DOI')
      expect(se_ident.identifier).to eq('10.15146/R3RG6G')
    end

    it 'extracts the files' do
      expected_time = wrapper.version_date.to_time
      se_file_uploads = se_resource.file_uploads
      expect(se_file_uploads.size).to eq(stash_files.size)
      stash_files.each_with_index do |sf, i|
        sef = se_file_uploads[i]
        expect(sef.upload_file_name).to eq(sf.pathname)
        expect(sef.upload_content_type).to eq(sf.mime_type.to_s)
        expect(sef.upload_file_size).to eq(sf.size_bytes)
        expect(sef.upload_updated_at.to_i).to be_within(120).of(expected_time.to_i)
        expect(sef.file_state).to eq('created')
      end
    end

    it 'extracts the creators' do
      creators = se_resource.creators
      expect(creators.size).to eq(1)
      creator = creators[0]
      expect(creator.creator_first_name).to eq('Hao')
      expect(creator.creator_last_name).to eq('Chen')
      name_ident = creator.name_identifier
      expect(name_ident.name_identifier).to eq('0123-4567-8910-1112')
      expect(name_ident.name_identifier_scheme).to eq('ORCID')
      expect(name_ident.scheme_URI).to eq('http://orcid.org/')
      affiliations = creator.affiliations
      expect(affiliations.size).to eq(1)
      affiliation = affiliations[0]
      expect(affiliation.long_name).to eq('North Carolina Central University')
    end

    it 'extracts the title' do
      titles = se_resource.titles
      expect(titles.size).to eq(2)
      title = titles[0]
      expect(title.title).to eq('A Zebrafish Model for Studies on Esophageal Epithelial Biology')
      subtitle = titles[1]
      expect(subtitle.title).to eq('Characterizing a region of stratified squamous epithelium in the zebrafish upper digestive tract')
      expect(subtitle.title_type).to eq(Datacite::Mapping::TitleType::SUBTITLE.value.downcase)
    end

    it 'extracts the publisher' do
      publisher = se_resource.publisher
      expect(publisher.publisher).to eq('DataONE')
    end

    it 'extracts the publication year' do
      publication_years = se_resource.publication_years
      expect(publication_years.size).to eq(1)
      publication_year = publication_years[0]
      expect(publication_year.publication_year).to eq(2016.to_s)
    end

    it 'extracts the subjects' do
      subjects = se_resource.subjects
      expect(subjects.size).to eq(3)
    end

    it 'extracts the funding' do
      contribs = se_resource.contributors
      funder_type = Datacite::Mapping::ContributorType::FUNDER.value.downcase
      funder_contribs = contribs.select { |c| c.contributor_type == funder_type }
      expect(funder_contribs.size).to eq(3)
      expected = [
        { contributor_name: 'U.S. Environmental Protection Agency', award_number: 'EPA STAR Fellowship 2011' },
        { contributor_name: 'CYBER-ShARE Center of Excellence National Science Foundation (NSF) CREST grants', award_number: 'HRD-0734825 and HRD-1242122' },
        { contributor_name: 'CI-Team Grant', award_number: 'OCI-1135525' }
      ]
      funder_contribs.each_with_index do |fc, i|
        expect(fc.contributor_name).to eq(expected[i][:contributor_name])
        expect(fc.award_number).to eq(expected[i][:award_number])
        expect(fc.affiliation).to be_nil
      end
    end

    it 'extracts the non-funding contributors' do
      funder_type = Datacite::Mapping::ContributorType::FUNDER.value.downcase
      contribs = se_resource.contributors
      contribs = contribs.select { |c| c.contributor_type != funder_type }
      expect(contribs.size).to eq(2)

      expect(contribs[0].contributor_name).to eq('Chen, Xiaoxin')
      expect(contribs[0].contributor_type).to eq(Datacite::Mapping::ContributorType::PROJECT_MEMBER.value.downcase)
      expect(contribs[0].affiliations.size).to eq(1)
      affiliation = contribs[0].affiliations[0]
      expect(affiliation.long_name).to eq('University of North Carolina at Chapel Hill')
      name_ident = contribs[0].name_identifier
      expect(name_ident.name_identifier).to eq('1234-5678-9101-1121')
      expect(name_ident.name_identifier_scheme).to eq('ORCID')
      expect(name_ident.scheme_URI).to eq('http://orcid.org/')

      expect(contribs[1].contributor_name).to eq('Wilson, James')
      expect(contribs[1].contributor_type).to eq(Datacite::Mapping::ContributorType::DATA_MANAGER.value.downcase)
      expect(contribs[1].affiliations.size).to eq(0)
      expect(contribs[1].name_identifier).to be_nil

      contribs.each { |c| expect(c.award_number).to be_nil }
    end

    it 'extracts the dates' do
      dates = se_resource.datacite_dates
      expect(dates.size).to eq(1)
      date = dates[0]
      expect(date.date).to eq(Date.new(2015, 12, 2))
      expect(date.date_type).to eq(Datacite::Mapping::DateType::AVAILABLE.value.downcase)
    end

    it 'extracts the language' do
      language = se_resource.language
      expect(language.language).to eq('en')
    end

    it 'extracts the resource type' do
      resource_type = se_resource.resource_type
      expect(resource_type.resource_type).to eq(Datacite::Mapping::ResourceTypeGeneral::DATASET.value.downcase)
    end

    it 'extracts the alternate identifiers' do
      alt_idents = se_resource.alternate_identifiers
      expect(alt_idents.size).to eq(1)
      alt_ident = alt_idents[0]
      expect(alt_ident.alternate_identifier).to eq('https://oneshare.cdlib.org/xtf/view?docId=dataone/ark%2B%3Dc5146%3Dr3rg6g/mrt-datacite.xml')
      expect(alt_ident.alternate_identifier_type).to eq('URL')
    end

    it 'extracts the related identifiers' do
      rel_idents = se_resource.related_identifiers
      expect(rel_idents.size).to eq(2)
      expected = [
        {
          relation_type: Datacite::Mapping::RelationType::IS_CITED_BY.value.downcase,
          id_type: Datacite::Mapping::RelatedIdentifierType::DOI.value.downcase,
          value: '10.1371/journal.pone.0143878'
        },
        {
          relation_type: Datacite::Mapping::RelationType::IS_DOCUMENTED_BY.value.downcase,
          id_type: Datacite::Mapping::RelatedIdentifierType::URL.value.downcase,
          value: 'http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0143878'
        }
      ]
      rel_idents.each_with_index do |ri, i|
        expect(ri.related_identifier).to eq(expected[i][:value])
        expect(ri.related_identifier_type).to eq(expected[i][:id_type])
        expect(ri.relation_type).to eq(expected[i][:relation_type])
      end
    end

    it 'extracts the sizes' do
      sizes = se_resource.sizes
      expect(sizes.size).to eq(1)
      expect(sizes[0].size).to eq(3_824_823.to_s)
    end

    it 'extracts the formats' do
      formats = se_resource.formats
      expected = [
        'text/plain',
        'text/application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/xml',
        'application/pdf'
      ]
      expect(formats.size).to eq(expected.size)
      formats.each_with_index do |f, i|
        expect(f.format).to eq(expected[i])
      end
    end

    it 'extracts the rights' do
      rights = se_resource.rights
      expect(rights.size).to eq(1)
      expect(rights[0].rights).to eq('CC0 1.0 Universal (CC0 1.0) Public Domain Dedication')
      expect(rights[0].rights_uri).to eq('https://creativecommons.org/publicdomain/zero/1.0/')
    end

    it 'extracts the descriptions' do
      descriptions = se_resource.descriptions
      expected = [
        {
          type: Datacite::Mapping::DescriptionType::ABSTRACT.value.downcase,
          value: 'Mammalian esophagus exhibits a remarkable change in epithelial
                  structure during the transition from embryo to adult. However, the
                  molecular mechanisms of esophageal epithelial development are not well
                  understood. Zebrafish (Danio rerio), a common model organism for
                  vertebrate development and gene function, has not previously been
                  characterized as a model system for esophageal epithelial development.
                  In this study, we characterized a piece of non-keratinized stratified
                  squamous epithelium similar to human esophageal epithelium in the
                  upper digestive tract of developing zebrafish. Under the microscope,
                  this piece was detectable at 5dpf and became stratified at 7dpf.
                  Expression of esophageal epithelial marker genes (Krt5, P63, Sox2
                  and Pax9) was detected by immunohistochemistry and in situ
                  hybridization. Knockdown of P63, a gene known to be critical for
                  esophageal epithelium, disrupted the development of this epithelium.
                  With this model system, we found that Pax9 knockdown resulted in loss
                  or disorganization of the squamous epithelium, as well as
                  down-regulation of the differentiation markers Krt4 and Krt5. In
                  summary, we characterized a region of stratified squamous epithelium
                  in the zebrafish upper digestive tract which can be used for
                  functional studies of candidate genes involved in esophageal epithelial biology.'
            .gsub(/\s+/, ' ')
        }
      ]
      expect(descriptions.size).to eq(expected.size)
      descriptions.each_with_index do |desc, i|
        expect(desc.description).to eq(expected[i][:value])
        expect(desc.description_type).to eq(expected[i][:type])
      end
    end

    it 'extracts the geolocations' do
      se_locations = se_resource.geolocations
      expected_places = [
        'Providence Creek (Lower, Upper and P301)',
        'Atlantic Ocean'
      ]
      se_place_ids = se_locations.map(&:place_id).compact
      places = GeolocationPlace.find(se_place_ids)
      expect(places.size).to eq(expected_places.size)
      places.each_with_index do |p, i|
        expect(p.geo_location_place).to eq(expected_places[i])
      end

      expected_boxes = [
        [37.046, -119.211, 37.075, -119.182],
        [41.09, -71.032, 42.893, -68.211]
      ]
      se_box_ids = se_locations.map(&:box_id).compact
      boxes = GeolocationBox.find(se_box_ids)
      expect(boxes.size).to eq(expected_boxes.size)
      boxes.each_with_index do |b, i|
        coords = [b.sw_latitude, b.sw_longitude, b.ne_latitude, b.ne_longitude]
        coords.each_with_index do |c, j|
          expect(c).to be_within(0.0001).of(expected_boxes[i][j])
        end
      end

      se_point_ids = se_locations.map(&:point_id).compact
      points = GeolocationPoint.find(se_point_ids)
      expect(points.size).to eq(1)
      point = points[0]
      expect(point.latitude).to be_within(0.0001).of(31.233)
      expect(point.longitude).to be_within(0.0001).of(-67.302)
    end
  end
end
