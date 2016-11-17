#!/usr/bin/env ruby

require 'ezid-client'

ezid_client = Ezid::Client.new(user: 'dash', password: 'dash')

dois = [
  "doi:10.5060/d8bc75",
  "doi:10.5060/d8g593",
  "doi:10.5060/d8kw2m",
  "doi:10.5060/d8z59f",
  "doi:10.5060/d86p4w",
  "doi:10.5060/d8301x",
  "doi:10.5060/D8RP4V",
  "doi:10.5060/D8H59D"
]

dois.each do |doi|
  target = "https://dash.ucop.edu/stash/dataset/#{doi}"
  ezid_client.modify_identifier(doi, target: target)
end
