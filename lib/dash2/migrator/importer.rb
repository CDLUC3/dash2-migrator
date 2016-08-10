require 'datacite/mapping'
require 'stash_ezid/client'

module Dash2
  module Migrator
    class Importer

      attr_reader :ezid_client
      attr_reader :user_uid
      attr_reader :stash_wrapper

      def initialize(stash_wrapper:, user_uid:, ezid_client:)
        @stash_wrapper = stash_wrapper
        @user_uid = user_uid
        @ezid_client = ezid_client
      end

      private

      def user
        @user ||= StashEngine::User.find_by_uid(user_uid)
      end

      def user_id
        @user_id ||= user.id
      end

      def datacite_resource
        @datacite_resource ||= begin
          datacite_xml = stash_wrapper.stash_descriptive[0]
          Datacite::Mapping::Resource.parse_xml(datacite_xml)
        end
      end

      def create_resource
        resource = StashEngine::Resource.create(user_id: user_id)
        resource_state = StashEngine::ResourceState.create(
          user_id: user_id,
          resource_state: 'in_progress',
          resource_id: resource.id
        )
        resource.update(current_resource_state_id: resource_state.id)
        resource
      end

    end
  end
end
