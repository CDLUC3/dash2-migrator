#!/usr/bin/env ruby

lib_path = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'dash2/migrator'
require 'dash2/reversioning'

stash_env = ENV['STASH_ENV']
raise '$STASH_ENV not set' unless stash_env
# raise 'Production migration not implemented' if stash_env == 'production'
ENV['RAILS_ENV'] = stash_env

Stash::LOG_LEVEL ||= Logger::DEBUG
config_file = case stash_env
  when 'development'
    'config/migrate-all-dev.yml'
  when 'stage'
    'config/migrate-all-stg.yml'
  else
    'config/migrate-all.yml'
end

job = Dash2::Migrator::MigrationJob.from_file(config_file)

db_config ||= begin
  stash_env = ENV['STASH_ENV']
  raise '$STASH_ENV not set' unless stash_env
  YAML.load_file(job.index_db_config_path)[stash_env]
end
ActiveRecord::Base.establish_connection(db_config)

job.sources.each do |source|
  tenant_path = source[:tenant_path]
  feed_uri = source[:feed_uri]
  Dash2::Reversioning::Reversionator.new(tenant_path: tenant_path, feed_uri: feed_uri).update!
end

