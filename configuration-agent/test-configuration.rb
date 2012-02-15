#!/usr/bin/env ruby

$LOAD_PATH << "/usr/lib/ruby/1.8"
require 'mcollective'

include MCollective::RPC

if !ARGV || ARGV.length != 1 then
  puts "Usage: test-configuration.rb URI"
  exit(-1)
end
url = ARGV[0]

configClient = rpcclient("configuration")
configClient.progress = false
configClient.set_registration_url(:URI => url).each do |resp|
  respData = resp[:data]
  if respData then
    printf("Registration Response: '%s' [from '%s' at %s]\n",
      respData[:Response], resp[:sender], respData[:Time])
  else
    printf("[%s] %s\n", resp[:sender], resp[:statusmsg])
  end
end
