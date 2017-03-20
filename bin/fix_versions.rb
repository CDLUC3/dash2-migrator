#!/usr/bin/env ruby

stash_env = ENV['STASH_ENV']

raise '$STASH_ENV not set' unless stash_env
raise 'Production migration not implemented' if stash_env == 'production'
ENV['RAILS_ENV'] = stash_env

lib_path = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'dash2/migrator'

Stash::LOG_LEVEL ||= Logger::DEBUG

include Dash2::Migrator

diffs = []

config_file = case stash_env
  when 'development'
    'config/migrate-all-dev.yml'
  when 'stage'
    'config/migrate-all-stg.yml'
  else
    'config/migrate-all.yml'
end

job = MigrationJob.from_file(config_file)
job.sources.each do |source|
  tenant_path = source[:tenant_path]
  feed_uri = source[:feed_uri]
  config = Harvester::MerrittAtomSourceConfig.new(
    tenant_path: tenant_path,
    feed_uri: feed_uri,
    user_provider: nil,
    env_name: stash_env
  )

  tenant = config.tenant_id
  puts "# #{tenant}\t#{feed_uri}"

  puts "ark\tdoi\tstash_version\tmerritt_version"

  harvest_task = Harvester::MerrittAtomHarvestTask.new(config: config)
  harvest_task.harvest_records.each do |record|
    ark = record.ark
    next unless ark

    doi = record.doi
    stash_version = record.stash_version
    merritt_version = record.merritt_version
    puts "#{ark}\t#{doi}\t#{stash_version}\t#{merritt_version}"

    if stash_version && (stash_version != merritt_version)
      diffs << {
        tenant: tenant,
        doi: doi,
        stash_version: stash_version,
        merritt_version: merritt_version,
      }
    end
  end
end

puts diffs.to_yaml

