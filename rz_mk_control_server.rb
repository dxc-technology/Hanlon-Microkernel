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

require 'net/http'
require 'cgi'
require 'json'
require 'yaml'
require 'logger'
require_relative 'rz_mk_registration_manager'
require_relative 'fact_manager'

# setup a logger for our "Keep-Alive" server...
logger = Logger.new('/tmp/rz_mk_controller.log', 5, 1024*1024)
logger.level = Logger::DEBUG
logger.formatter = proc do |severity, datetime, progname, msg|
  "(#{severity}) [#{datetime.strftime("%Y-%m-%d %H:%M:%S")}]: #{msg}\n"
end

# setup the FactManager instance (we'll use this later, in our
# RzMkRegistrationManager constructor)
fact_manager = FactManager.new('/tmp/prev_facts.yaml')

# load the Microkernel Configuration, use the parameters in that configuration
# to control the
mk_config_file = '/tmp/mk_conf.yaml'
registration_manager = nil

if (File.exist?(mk_config_file)) then
  mk_conf = YAML::load(File.open(mk_config_file))

  # now, load a few items from that mk_conf map, first the URI for
  # the server
  razor_uri = mk_conf[:mk][:razor_uri]
  # add the "node register" entry from the same configuration map to
  # get the registration URI
  registration_uri = razor_uri + mk_conf[:node][:register]

  # next, the time (in secs) to sleep between iterations of the main
  # loop (below)
  checkin_sleep = mk_conf[:mk][:checkin_sleep]

  # next, the maximum amount of time to wait (in secs) the before starting
  # the main loop (below); a random number between zero and that amount of
  # time will be determined and used to ensure microkernel instances are
  # offset from each other when it comes to tasks like reporting facts to
  # the Razor server
  checkin_offset = mk_conf[:mk][:checkin_offset]

  # this parameter defines which facts (by name) should be excluded from the
  # map that is reported during node registration
  exclude_pattern = mk_conf[:facts][:exclude_pattern]
  registration_manager = RzMkRegistrationManager.new(registration_uri,
                                    exclude_pattern, fact_manager, logger)

else

  registration_uri = ''
  checkin_sleep = 30
  checkin_offset = 5

end

msecs_sleep = checkin_sleep * 1000;
msecs_offset = checkin_offset * 1000;

# generate a random number between zero and msecs_offset and sleep for that
# amount of time
rand_secs = rand(msecs_offset) / 1000.0
logger.debug "Sleeping for #{rand_secs} seconds"
sleep(rand_secs)

# and enter the main event-handling loop
loop do
  t1 = Time.now
  # send a "keep-alive" message to the server; handle the reply
  # if reply[:action] == "ack" then
  #   noop()
  # else if reply[:action] == "register" && registration_manager != nil then
  #   registration_manager.register_node
  # else if reply[:action] == "reboot" then
  #   trigger_node_reboot()
  # end

  if (t1 > fact_manager.last_saved_timestamp) then
    # haven't saved the facts since we started this iteration, so need to check
    # to see if the facts have changed since our last registration and, if so
    # re-register this node
    registration_manager.register_node_if_changed
  end

  # check to see how much time has elapsed, sleep for the time remaining
  # in the msecs_sleep time window
  t2 = Time.now
  msecs_elapsed = (t2 - t1) * 1000
  if (msecs_elapsed < msecs_sleep) then
    secs_sleep = (msecs_sleep - msecs_elapsed)/1000.0
    logger.debug "Time remaining: #{secs_sleep} seconds..."
    sleep(secs_sleep) if secs_sleep >= 0.0
  end
end
