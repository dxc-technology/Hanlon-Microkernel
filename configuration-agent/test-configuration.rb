#!/usr/bin/env ruby

require 'mcollective'

include MCollective::RPC

if !ARGV || ARGV.length != 1 then
  puts "Usage: test-configuration.rb URL"
  exit(-1)
end
url = ARGV[0]

configClient = rpcclient("configuration")
configClient.progress = false
configClient.set_registration_url(:URL => url).each do |resp|
  respData = resp[:data]
  if respData then
    printf("Received: '%s' [by '%s' at %s]\n",
      respData[:URL], resp[:sender], respData[:time])
  else
    printf("[%s] %s\n", resp[:sender], resp[:statusmsg])
  end
end
