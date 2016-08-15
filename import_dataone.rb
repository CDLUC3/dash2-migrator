#!/usr/bin/env ruby

include 'lib/dash2/migrator.rb'
require 'stash/harvester_app'

config_file = 'config/migrator-dataone.yml'
app = Stash::HarvesterApp::Application.with_config_file(config_file)
