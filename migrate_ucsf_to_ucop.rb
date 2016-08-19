#!/usr/bin/env ruby

# ############################################################
# Includes / Requires

lib_path = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'stash/harvester_app'
require 'dash2/migrator'

# ############################################################
# Check environment

ENV['STASH_ENV'] ||= 'test'
raise 'Production migration not implemented' if ENV['STASH_ENV'] == 'production'

# ############################################################
# Configure users

class Dash2::Migrator::MerrittAtomHarvestedRecord
  def self.ucop_users
    @ucop_users ||= begin
      ucop_users = StashEngine::User.where(tenant_id: 'ucop').all
      if ucop_users.empty?
        [StashEngine::User.create(
          uid: 'lmuckenhaupt-ucop@ucop.edu',
          first_name: 'Lisa',
          last_name: 'Muckenhaupt',
          email: 'lmuckenhaupt@ucop.edu',
          provider: 'developer',
          tenant_id: 'ucop'
        )]
      else
        ucop_users
      end
    end
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
    @user_uid ||= Dash2::Migrator::MerrittAtomHarvestedRecord.next_uid
  end
end

# ############################################################
# Harvest

config_files = [
    'config/migrator-ucsf-to-ucop.yml',
    'config/migrator-ucsf2-to-ucop.yml'
]

config_files.each do |config_file|
  Stash::HarvesterApp::Application.with_config_file(config_file).start
end


