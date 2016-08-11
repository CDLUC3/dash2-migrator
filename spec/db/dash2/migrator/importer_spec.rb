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
        end
      end

      describe 'DOI handling' do
        it 'mints a DOI in demo mode'
        it 'updates the DOI in production mode'
      end
    end
  end
end
