require 'stash/harvester/source_config'

module Dash2
  module Migrator
    module Harvester
      class MerrittAtomSourceConfig < Stash::Harvester::SourceConfig
        protocol 'Merritt Atom'

        attr_reader :tenant_path

        def initialize(tenant_path:, feed_uri:, env_name: nil)
          super(source_url: feed_uri)
          @env_name = env_name
          @tenant_path = File.absolute_path(tenant_path)
        end

        def description
          @desc = begin
            desc = "Merritt Atom source for #{tenant_path} (#{feed_uri})"
            desc << " #{env_name}" if env_name
            desc
          end
        end

        def tenant_config
          @tenant_config ||= begin
            tenant_config = YAML.load_file(tenant_path)
            tenant_config[env_name.to_s]
          end
        end

        def repo_config
          tenant_config['repository']
        end

        def username
          repo_config['username']
        end

        def password
          repo_config['password']
        end

        def feed_uri
          @feed_uri ||= URI.parse(source_uri.to_s.sub('https://', "https://#{username}:#{password}@"))
        end

        def create_harvest_task(from_time: nil, until_time: nil)
          MerrittAtomHarvestTask.new(config: self, from_time: from_time, until_time: until_time)
        end
      end
    end
  end
end
