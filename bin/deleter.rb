#!/usr/bin/env ruby

stash_env = ENV['STASH_ENV']
raise '$STASH_ENV not set' unless stash_env
# raise 'Production migration not implemented' if stash_env == 'production'
ENV['RAILS_ENV'] = stash_env

require 'stash_engine'

Stash::LOG_LEVEL ||= Logger::DEBUG

# TODO: simplify / standardize this
stash_engine_path = Gem::Specification.find_by_name('stash_engine').gem_dir
require "#{stash_engine_path}/config/initializers/hash_to_ostruct.rb"
require "#{stash_engine_path}/config/initializers/repository.rb"
require "#{stash_engine_path}/config/initializers/inflections.rb"

# TODO: MockRails.application.root and use stash_engine/config/initializers/licenses.rb
::LICENSES ||= YAML.load_file('config/licenses.yml').with_indifferent_access
# TODO: as above, but also move /config/initializers/app_config.rb from dash2 into stash_engine
# ::APP_CONFIG = OpenStruct.new(YAML.load_file('config/app_config.yml')['test'])

# Note: Even if we're not doing any database work, ActiveRecord callbacks will still raise warnings
ActiveRecord::Base.raise_in_transactional_callbacks = true

%w(
  app/models/stash_engine
  lib/stash_engine
).each do |dir|
  Dir.glob("#{stash_engine_path}/#{dir}/**/*.rb").sort.each(&method(:require))
end

db_config_path = 'config/database.yml'
db_config = YAML.load_file(db_config_path)[stash_env]
ActiveRecord::Base.establish_connection(db_config)

include StashEngine

dois = %w[
  10.15146/R3160X
  10.15146/R3WG6Q
  10.15146/R3RP55
  10.15146/R3N01T
  10.15146/R3H880
  10.15146/R3CG62
  10.15146/R37S3S
  10.15146/R34015
  10.15146/R3088B
  10.15146/R3VG6D
]

# dois = %w[
# 10.5072/FK2CC11J21
# 10.5072/FK27M09Q6Z
# ]

dois.each do |doi|
  identifier = Identifier.find_by(identifier: doi)
  puts "No such identifier #{doi}" unless identifier
  next unless identifier
  puts "Deleting resources for DOI #{doi}"
  identifier.resources.destroy_all
  puts "Deleting identifier for DOI #{doi}"
  identifier.destroy
end

# TODO: Clean up tables not caught by the above:

# DELETE FROM dcs_alternate_identifiers WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_contributors WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_dates WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_descriptions WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_formats WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_geo_locations WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_languages WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_publication_years WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_publishers WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_related_identifiers WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_resource_types WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_rights WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_sizes WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_subjects_stash_engine_resources WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_titles WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM dcs_versions WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM stash_engine_authors WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM stash_engine_embargoes WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM stash_engine_file_uploads WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM stash_engine_resource_states WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM stash_engine_resource_usages WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM stash_engine_shares WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM stash_engine_submission_logs WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
# DELETE FROM stash_engine_versions WHERE resource_id IN (349, 350, 351, 352, 353, 354, 355, 356, 357, 358);
