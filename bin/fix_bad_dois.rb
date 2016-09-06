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
# Configure users

class Dash2::Migrator::Harvester::MerrittAtomHarvestedRecord
  def self.ucop_users
    @ucop_users ||= begin
      ucop_users = StashEngine::User.where(tenant_id: 'ucop').all
      if ucop_users.empty?
        [create_default_user!]
      else
        ucop_users
      end
    end
  end

  def self.create_default_user!
    StashEngine::User.create(
      uid: 'lmuckenhaupt-ucop@ucop.edu',
      first_name: 'Lisa',
      last_name: 'Muckenhaupt',
      email: 'lmuckenhaupt@ucop.edu',
      provider: 'developer',
      tenant_id: 'ucop'
    )
  end

  def self.next_uid_index
    @uid_index ||= -1
    next_index = @uid_index + 1
    @uid_index = next_index < ucop_users.size ? next_index : 0
  end

  def self.next_uid
    ucop_users[next_uid_index].uid
  end

  def user_uid
    @user_uid ||= Dash2::Migrator::Harvester::MerrittAtomHarvestedRecord.next_uid
  end
end

class Dash2::Migrator::Importer
  def import(stash_wrapper:, user_uid:)
    # find all previously migrated for this wrapper's old DOI
    # ()do nothing if there aren't any)
    # for each:
    #   inject the new DOI into the stash wrapper and datacite XML
    #   use a non-minting DOI updater to update the metadata
    #   submit a SWORD update
  end
end

# ############################################################
# Migrate

migrator = Dash2::Migrator::MigrationJob.from_file('config/migrate-all-to-ucop.yml')
migrator.migrate!
