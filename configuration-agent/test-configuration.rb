#!/usr/bin/env ruby

$LOAD_PATH << "/usr/lib/ruby/1.8"
require 'mcollective'
require 'yaml'
require 'json'

include MCollective::RPC

if !ARGV || ARGV.length != 1 then
  puts "Usage: test-configuration.rb mk_conf_filename"
  exit(-1)
end
mk_conf_filename = ARGV[0]

# load the Microkernel Configuration from the input (YAML) file;
# contents of this file should look something like the following:
#   ---
#   :mk:
#     :razor_uri: http://192.168.5.2:8026
#     :checkin_sleep: 60
#     :checkin_offset: 5
#   :facts:
#     :exclude_pattern: /(^uptime.*$)|(^memory.*$)/
#   :node:
#     :register: /razor/api/node/register
#     :checkin: /razor/api/node/checkin

mk_conf = YAML::load(File.open(mk_conf_filename, 'r'))

# then convert the resulting Hash map into a JSON string
json_string = JSON.generate(mk_conf)

# now that the setup is complete, create an rpcclient to connect to our
# MCollective agents (and configure it so that it doesn't report progress)
configClient = rpcclient("configuration")
configClient.progress = false

# and invoke the action on our agents that will set the Microkernel Config
# using the json_string generated (above)
configClient.set_mk_config(:configuration => json_string).each do |resp|
  respData = resp[:data]
  if respData then
    printf("Registration Response: '%s' [from '%s' at %s]\n",
      respData[:Response], resp[:sender], respData[:Time])
  else
    printf("[%s] %s\n", resp[:sender], resp[:statusmsg])
  end
end
