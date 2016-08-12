require 'db_spec_helper'

module Dash2
  module Migrator
    describe Dash2Indexer do

      attr_reader :index_config
      # attr_reader :ezid_shoulder
      # attr_reader :ezid_account
      # attr_reader :ezid_password
      attr_reader :ezid_client
      attr_reader :user_uid
      attr_reader :wrapper
      attr_reader :importer

      before(:all) do
        @user_uid = 'lmuckenhaupt-ucop@ucop.edu'

        path = 'config/migrator-dataone.yml'
        @index_config = Stash::Config.from_file(path).index_config
        # @ezid_shoulder ='doi:10.5072/FK2'
        # @ezid_account = 'apitest'
        # @ezid_password = 'apitest'
        # @ezid_client ||= StashEzid::Client.new(
        #     shoulder: ezid_shoulder,
        #     account: ezid_account,
        #     password: ezid_password,
        #     id_scheme: 'doi',
        #     owner: 'apitest'
        # )
        ezid_client = instance_double(StashEzid::Client)

        wrapper_xml = File.read('/Users/dmoles/Work/dash2-migrator/spec/data/harvested-wrapper.xml')
        @wrapper = Stash::Wrapper::StashWrapper.parse_xml(wrapper_xml)
        @importer = Importer.new(stash_wrapper: wrapper, user_uid: user_uid, ezid_client: ezid_client)
      end

      describe 'imports' do
        attr_reader :imported

        before(:each) do
          StashEngine::User.create(
            uid: user_uid,
            first_name: 'Lisa',
            last_name: 'Muckenhaupt',
            email: 'lmuckenhaupt@example.org',
            provider: 'developer',
            tenant_id: 'ucop'
          )
          @imported = importer.import
        end

        it 'imports a record' do
          expect(imported).to be_a(StashEngine::Resource)
        end

        it 'extracts the creators' do
          creators = imported.creators
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
          titles = imported.titles
          expect(titles.size).to eq(2)
          title = titles[0]
          expect(title.title).to eq('A Zebrafish Model for Studies on Esophageal Epithelial Biology')
          subtitle = titles[1]
          expect(subtitle.title).to eq('Characterizing a region of stratified squamous epithelium in the zebrafish upper digestive tract')
          expect(subtitle.title_type).to eq(Datacite::Mapping::TitleType::SUBTITLE.value.downcase)
        end

        it 'extracts the publisher' do
          publisher = imported.publisher
          expect(publisher.publisher).to eq('DataONE')
        end

        it 'extracts the publication year' do
          publication_years = imported.publication_years
          expect(publication_years.size).to eq(1)
          publication_year = publication_years[0]
          expect(publication_year.publication_year).to eq(2016.to_s)
        end

        it 'extracts the subjects' do
          subjects = imported.subjects
          expect(subjects.size).to eq(3)
        end

        it 'extracts the funding' do
          contribs = imported.contributors
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
          contribs = imported.contributors
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
          dates = imported.datacite_dates
          expect(dates.size).to eq(1)
          date = dates[0]
          expect(date.date).to eq(Date.new(2015, 12, 2))
          expect(date.date_type).to eq(Datacite::Mapping::DateType::AVAILABLE.value.downcase)
        end

        it 'extracts the language' do
          language = imported.language
          expect(language.language).to eq('en')
        end

        it 'extracts the resource type' do
          resource_type = imported.resource_type
          expect(resource_type.resource_type).to eq(Datacite::Mapping::ResourceTypeGeneral::DATASET.value.downcase)
        end

        it 'extracts the alternate identifiers' do
          alt_idents = imported.alternate_identifiers
          expect(alt_idents.size).to eq(1)
          alt_ident = alt_idents[0]
          expect(alt_ident.alternate_identifier).to eq('https://oneshare.cdlib.org/xtf/view?docId=dataone/ark%2B%3Dc5146%3Dr3rg6g/mrt-datacite.xml')
          expect(alt_ident.alternate_identifier_type).to eq('URL')
        end

        it 'extracts the related identifiers' do
          rel_idents = imported.related_identifiers
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
          sizes = imported.sizes
          expect(sizes.size).to eq(1)
          size = sizes[0]
          expect(size.size).to eq(3_824_823.to_s)
        end

        it 'extracts the formats' do
          formats = imported.formats
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

        it 'extracts the version' do
          version = imported.version
          expect(version).not_to be_nil
          expect(version.version).to eq('3.1')
        end

        it 'extracts the rights' do
          rights = imported.rights
          expect(rights.size).to eq(1)
          expect(rights[0].rights).to eq('CC0 1.0 Universal (CC0 1.0) Public Domain Dedication')
          expect(rights[0].rights_uri).to eq('https://creativecommons.org/publicdomain/zero/1.0/')
        end

        it 'extracts the descriptions' do
          descriptions = imported.descriptions
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
                .squeeze(' ')
            }
          ]
          expect(descriptions.size).to eq(expected.size)
          descriptions.each_with_index do |desc, i|
            expect(desc.description).to eq(expected[i][:value])
            expect(desc.description_type).to eq(expected[i][:type])
          end

        end
      end

      describe 'DOI handling' do
        it 'mints a DOI in demo mode'
        it 'updates the DOI in production mode'
      end
    end
  end
end
