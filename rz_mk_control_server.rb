#!/usr/bin/env ruby

# this is rz_mk_control_server.rb
# it starts up a WEBrick server that can be used to control the Microkernel
# (commands to the Microkernel are invoked using Servlets running in the
# WEBrick instance)
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

require 'rubygems'
#require 'logger'
require 'net/http'
require 'cgi'
require 'json'
require 'yaml'
require 'facter'
require 'razor_microkernel/logging'
require 'razor_microkernel/rz_mk_registration_manager'
require 'razor_microkernel/rz_mk_fact_manager'
require 'razor_microkernel/rz_mk_configuration_manager'

# set up a global variable that will be used in the RazorMicrokernel::Logging mixin
# to determine where to place the log messages from this script
RZ_MK_LOG_PATH = "/var/log/rz_mk_controller.log"

# include the RazorMicrokernel::Logging mixin (which enables logging)
include RazorMicrokernel::Logging

# get a reference to the Configuration Manager instance (a singleton)
config_manager = (RazorMicrokernel::RzMkConfigurationManager).instance

# setup the RzMkFactManager instance (we'll use this later, in our
# RzMkRegistrationManager constructor)
fact_manager = RazorMicrokernel::RzMkFactManager.new('/tmp/prev_facts.yaml')

# and set the Registration Manager to nil (will update this, below)
registration_manager = nil

# test to see if the configuration file exists
if config_manager.config_file_exists? then

  # load the Microkernel Configuration, use the parameters in that
  # configuration to setup the Microkernel Controller
  config_manager.load_current_config

  # now, load a few items from the configuration manager, first the log
  # level that the Microkernel should use
  logger.level = config_manager.mk_log_level

  # Next, grab the URI for the Razor Server
  razor_uri = config_manager.mk_uri

  # add the "node register" entry from the configuration map to that URI
  # to get the registration URI
  registration_uri = razor_uri + config_manager.mk_register_path
  logger.debug "registration_uri = #{registration_uri}"

  # and add the 'node checkin' entry from the configuration map to that URI
  # to get the checkin URI
  checkin_uri = razor_uri + config_manager.mk_checkin_path
  logger.debug "checkin_uri = #{checkin_uri}"

  # next, the time (in secs) to sleep between iterations of the main
  # loop (below)
  checkin_interval = config_manager.mk_checkin_interval

  # next, the maximum amount of time to wait (in secs) the before starting
  # the main loop (below); a random number between zero and that amount of
  # time will be determined and used to ensure Microkernel instances are
  # offset from each other when it comes to tasks like reporting facts to
  # the Razor server
  checkin_skew = config_manager.mk_checkin_skew

  # this parameter defines which facts (by name) should be excluded from the
  # map that is reported during node registration
  exclude_pattern = config_manager.mk_fact_excl_pattern
  logger.debug "exclude_pattern = #{exclude_pattern}"
  registration_manager = RazorMicrokernel::RzMkRegistrationManager.new(registration_uri,
                                                                       exclude_pattern, fact_manager)

else

  checkin_uri = nil
  checkin_interval = 30
  checkin_skew = 5

end

# convert the sleep times to milliseconds (for generating random skew value
# and calculation of time remaining in each iteration; these will be to
# the nearest millisecond)
msecs_sleep = checkin_interval * 1000;
max_skew_msecs = checkin_skew * 1000;

# generate a random number between zero and max_skew_msecs (in milliseconds)
# and sleep for that amount of time (in seconds)
rand_secs = rand(max_skew_msecs) / 1000.0
logger.info "Sleeping for #{rand_secs} seconds"
sleep(rand_secs)

idle = 'idle'

# and enter the main event-handling loop
loop do

  begin
    # grab the current time (used for calculation of the wait time and for
    # determining whether or not to register the node if the facts have changed
    # later in the event-handling loop)
    t1 = Time.now

    # if the checkin_uri was defined, then send a "checkin" message to the server
    if checkin_uri
      uuid = Facter.hostname[2..-1]     # subset to remove the 'mk' prefix
      checkin_uri_string = checkin_uri + "?uuid=#{uuid}&last_state=#{idle}"
      logger.info "checkin_uri_string = #{checkin_uri_string}"
      uri = URI checkin_uri_string

      # then,handle the reply (could include a command that must be handled)
      response = Net::HTTP.get(uri)
      logger.debug "checkin response => #{response}"
      response_hash = JSON.parse(response)
      # if error code is 0 ()indicating a successful checkin), then process the response
      if response_hash['errcode'] == 0 then
        # first, trigger appropriate action based on the command in the response
        command = response_hash['response']['command_name']
        if command == "acknowledge" then
          logger.debug "Received #{command} from #{checkin_uri_string}"
        elsif registration_manager && command == "register" then
          logger.debug "Register command received, registering the node"
          registration_manager.register_node(idle)
        elsif command == "reboot" then
          # reboots the node, NOW...no sense in logging this since the "filesystem"
          # is all in memory and will disappear when the reboot happens
          %x[sudo reboot now]
        end
        # next, check the configuration that is included in the response...
        config_map = response_hash['client_config']
        if config_map
          # check to see if the configuration from the response is different from the current
          # Microkernel Controller configuration
          if config_manager.mk_config_has_changed?(config_map)
            # If it has changed, then post the new configuration to the WEBrick instance
            # (which will trigger a restart of this Microkernel Controller instance)
            config_map_string = JSON.generate(config_map)
            logger.debug "Posting config to WEBrick server => #{config_map_string}"
            uri = URI "http://localhost:2156/setMkConfig"
            res = Net::HTTP.post_form(uri, config_map_string)
            # probably won't ever get here (the reboot from the WEBrick instance will intervene)
            # but, just in case...
            logger.debug "Response received back => #{res.body}"
          end
        end
      end
    end

    # if we haven't saved the facts since we started this iteration, then we
    # need to check to see whether or not the facts have changed since our last
    # registration; if so, then we need to re-register this node
    if registration_manager && t1 > fact_manager.last_saved_timestamp then
      registration_manager.register_node_if_changed(idle)
    end

  rescue
    logger.error("An exception occurred: #{$!}")
  end

  # check to see how much time has elapsed, sleep for the time remaining
  # in the msecs_sleep time window
  t2 = Time.now
  msecs_elapsed = (t2 - t1) * 1000
  if msecs_elapsed < msecs_sleep then
    secs_sleep = (msecs_sleep - msecs_elapsed)/1000.0
    logger.info "Time remaining: #{secs_sleep} seconds..."
    sleep(secs_sleep) if secs_sleep >= 0.0
  end

end
