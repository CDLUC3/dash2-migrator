#!/usr/bin/env ruby

require 'dash2/migrator'
require 'dash2/reversioning'

stash_env = ENV['STASH_ENV']

raise '$STASH_ENV not set' unless stash_env
raise 'Production migration not implemented' if stash_env == 'production'
ENV['RAILS_ENV'] = stash_env

lib_path = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

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
job.sources.each do |source|
  tenant_path = source[:tenant_path]
  feed_uri = source[:feed_uri]
  Dash2::Reversioning::Reversionator.new(tenant_path: tenant_path, feed_uri: feed_uri).update!
end

# diffs = []
# job = MigrationJob.from_file(config_file)
# job.sources.each do |source|
#   tenant_path = source[:tenant_path]
#   feed_uri = source[:feed_uri]
#   config = Harvester::MerrittAtomSourceConfig.new(
#     tenant_path: tenant_path,
#     feed_uri: feed_uri,
#     user_provider: nil,
#     env_name: stash_env
#   )
#
#   tenant = config.tenant_id
#   puts "# #{tenant}\t#{feed_uri}"
#
#   harvest_task = Harvester::MerrittAtomHarvestTask.new(config: config)
#   harvest_task.harvest_records.each do |record|
#     ark = record.ark
#     next unless ark
#
#     doi = record.doi
#     last_merritt_version = record.merritt_version
#     last_stash_version = record.stash_version
#
#     # TODO: get this into something we can test
#
#     identifier = StashEngine::Identifier.find_by(identifier: doi)
#     unless identifier
#       Stash::Harvester.log.warn("No database record for identifier #{doi}; skipping")
#       next
#     end
#
#     diff = last_merritt_version - last_stash_version
#     if diff != 0
#       submitted = (resources = identifier.resources) && resources.submitted
#       submitted.each do |v|
#         v.merritt_version += diff
#         v.save!
#       end
#     end
#
#   end
# end
