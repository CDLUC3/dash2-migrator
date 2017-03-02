#!/usr/bin/env ruby

ENV['STASH_ENV'] ||= 'production'
raise 'Test migration not implemented' unless ENV['STASH_ENV'] == 'production'
ENV['RAILS_ENV'] = ENV['STASH_ENV']

lib_path = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'dash2/migrator'

config = Dash2::Migrator::Harvester::MerrittAtomSourceConfig.new(
  tenant_path: 'config/tenants/ucb.yml',
  feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5q82t8x',
  user_provider: nil,
  env_name: 'production'
)

harvest_task = Dash2::Migrator::Harvester::MerrittAtomHarvestTask.new(config: config)

harvest_task.harvest_records.each do |record|
  doi = record.doi
  if doi == '10.6078/D1KS3M'
    wrapper = record.as_wrapper
    wrapper.version.version_number = 4
    wrapper_xml = wrapper.write_xml
    File.open('tmp/stash-wrapper.xml', 'w') { |f| f.write(wrapper_xml) }
    puts(wrapper_xml)
    exit(0)
  end
end
