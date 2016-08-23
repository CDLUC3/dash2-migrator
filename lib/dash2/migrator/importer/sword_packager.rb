require 'stash_engine'
require 'stash/sword'

module Dash2
  module Migrator
    module Importer

      class SwordPackager
        attr_reader :sword_client

        def initialize(sword_client:)
          @sword_client = SwordPackager.sword_client(sword_client)
        end

        def self.sword_client(client)
          return client if client.respond_to?(:create) && client.respond_to?(:update)
          return client if client.to_s =~ /InstanceDouble\(Stash::Sword::Client\)/ # For RSpec tests
          raise ArgumentError, "sword_client does not appear to be a Stash::Sword::Client: #{client || 'nil'}"
        end
      end

    end
  end
end
