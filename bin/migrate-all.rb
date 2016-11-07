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

# ############################################################
# Migrate

job = Dash2::Migrator::MigrationJob.from_file('config/migrate-all.yml')
job.migrate!

Dash2::Migrator::Importer::Importer.clean_up!
