#!/usr/bin/env ruby
#
# A demo SimpleRPC client that interacts with the facter agent to gather
# facts through the MCollective
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

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
