#!/usr/bin/env ruby

# this is rz_mk_control_server.rb
# it starts up a WEBrick server that can be used to control the Microkernel
# (commands to the Microkernel are invoked using Servlets running in the
# WEBrick instance)

# adds a "require_relative" function to the Ruby Kernel if it
# doesn't already exist (used to deal with the fact that
# "require" is used instead of "require_relative" prior
# to Ruby v1.9.2)
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require 'logger'
require 'net/http'
require 'cgi'
require 'json'
require 'yaml'
require 'daemons'
require_relative 'registration_manager'

# setup a logger for our Microkernel Controller...
logger = Logger.new('/var/log/rz_mk_controller.log', 5, 1024*1024)
logger.formatter = proc do |severity, datetime, progname, msg|
  "(#{severity}) [#{datetime.strftime("%Y-%m-%d %H:%M:%S")}]: #{msg}\n"
end
logger.level = Logger::DEBUG

# load the Microkernel Configuration, use the parameters in that configuration
# to control the
mk_config_file = '/tmp/mk_conf.yaml'
mk_conf = YAML::load(File.open(mk_conf_file))

# now, load a few items from that mk_conf map, first the URI for the server
razor_uri = mk_conf[:mk][:razor_uri]
# add the "node register" entry from the same configuration map to get the
# registration URI
registration_uri = razor_uri + mk_conf[:node][:register]

# next, the time (in secs) to sleep between iterations of the main loop (below)
checkin_sleep = mk_conf[:mk][:checkin_sleep]

# next, the maximum amount of time to wait (in secs) the before starting
# the main loop (below); a random number between zero and that amount of time
# will be determined and used to ensure microkernel instances are offset from
# each other when it comes to tasks like reporting facts to the Razor server
checkin_offset = mk_conf[:mk][:checkin_offset]

# this parameter defines which facts (by name) should be excluded from the
# map that is reported during node registration
exclude_pattern = mk_conf[:facts][:exclude_pattern]

registration_manager = RzMkRegistrationManager.new(registration_uri, exclude_pattern)

loop do
  # code to send our HTTP request and receive the reply back goes here
  # if action == ack; noop()
  # else if action == register; registration_manager.register_node()
  # else if action == reboot; trigger_node_reboot()
end
