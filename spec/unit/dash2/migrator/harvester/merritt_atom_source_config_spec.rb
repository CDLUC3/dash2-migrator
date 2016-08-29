require 'spec_helper'

module Dash2
  module Migrator
    module Harvester
      describe MerrittAtomSourceConfig do
        describe '#description' do

          attr_reader :base_feed_uri
          attr_reader :tenant_path
          attr_reader :env_name
          attr_reader :config

          before(:each) do
            @base_feed_uri = 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd'
            @tenant_path = File.absolute_path('config/tenants/example.yml')
            @env_name = 'test'
            @config = MerrittAtomSourceConfig.new(
              tenant_path: tenant_path,
              feed_uri: base_feed_uri,
              env_name: env_name
            )
          end

          it 'includes all relevant fields' do
            desc = config.description
            [base_feed_uri.sub('https://', ''), tenant_path, env_name].each do |f|
              expect(desc).to match(/#{Regexp.escape(f)}/)
            end
          end
        end
      end
    end
  end
end
