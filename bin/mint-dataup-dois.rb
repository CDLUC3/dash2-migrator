#!/usr/bin/env ruby

# ############################################################
# Check environment

ENV['STASH_ENV'] ||= 'test'
raise 'Production migration not implemented' if ENV['STASH_ENV'] == 'production'
ENV['RAILS_ENV'] = ENV['STASH_ENV']

# ############################################################
# Includes / Requires

lib_path = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'dash2/migrator'

source_config = Dash2::Migrator::Harvester::MerrittAtomSourceConfig.new(
  tenant_path: 'config/tenants/dataone.yml',
  feed_uri: 'https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5222s39',
  env_name: ENV['STASH_ENV']
)

harvest_task = source_config.create_harvest_task
harvest_task.harvest_records.each do |hr|
  puts hr.ark
end
