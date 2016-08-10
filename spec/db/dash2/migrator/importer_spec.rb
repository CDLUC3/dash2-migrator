require 'db_spec_helper'

module Dash2
  module Migrator
    describe Dash2Indexer do

      attr_reader :index_config
      # attr_reader :ezid_shoulder
      # attr_reader :ezid_account
      # attr_reader :ezid_password
      attr_reader :ezid_client

      before(:all) do
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
      end

      it 'imports a record' do
        wrapper_xml = File.read('/Users/dmoles/Work/dash2-migrator/spec/data/harvested-wrapper.xml')
        wrapper = Stash::Wrapper.parse_xml(wrapper_xml)
        importer = Importer.new(stash_wrapper: wrapper, user_uid: 'david.moles@ucop.edu', ezid_client: ezid_client)

      end

    end
  end
end
