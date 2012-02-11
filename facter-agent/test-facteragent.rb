#!/usr/bin/env ruby

$LOAD_PATH << "/usr/share/mcollective/lib"
require 'mcollective'
require 'yaml'

include MCollective::RPC

mc = rpcclient("facteragent")
mc.progress = false
mc.getall().each do |resp|
  respData = resp[:data]
  facts_hash = YAML.load(respData[:facts])
  p facts_hash
end
