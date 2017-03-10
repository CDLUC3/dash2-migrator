#!/usr/bin/env ruby

ENV['STASH_ENV'] ||= 'production'
raise 'Test migration not implemented' unless ENV['STASH_ENV'] == 'production'
ENV['RAILS_ENV'] = ENV['STASH_ENV']

lib_path = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'dash2/migrator'

Stash::LOG_LEVEL ||= Logger::DEBUG

include Dash2::Migrator

diffs = []

job = MigrationJob.from_file('config/migrate-all.yml')
job.sources.each do |source|
  tenant_path = source[:tenant_path]
  feed_uri = source[:feed_uri]
  config = Harvester::MerrittAtomSourceConfig.new(
    tenant_path: tenant_path,
    feed_uri: feed_uri,
    user_provider: nil,
    env_name: ENV['STASH_ENV']
  )

  tenant = config.tenant_id
  puts "# #{tenant}\t#{feed_uri}"

  harvest_task = Harvester::MerrittAtomHarvestTask.new(config: config)
  harvest_task.harvest_records.each do |record|
    doi = record.doi
    stash_version = record.stash_version
    merritt_version = record.merritt_version
    puts "#{doi}\t#{stash_version}\t#{merritt_version}"

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

