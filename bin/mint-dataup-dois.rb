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

require 'stash_ezid/client'

ezid_config = {
  shoulder: 'doi:10.5072/FK2',
  account: 'apitest',
  password: 'apitest',
  id_scheme: 'doi',
  owner: nil
}

ezid_client = StashEzid::Client.new(ezid_config)
inner_client = ezid_client.instance_variable_get(:@ezid_client)
if inner_client && (logger = inner_client.logger)
  logger.level = Logger::WARN
end

File.readlines('spec/data/all_dataup_arks.txt').each do |line|
  ark = line.strip
  next if ark == 'ark:/90135/q1f769jn' # oops
  doi = ezid_client.mint_id
  puts "#{ark}\t#{doi}"
end
