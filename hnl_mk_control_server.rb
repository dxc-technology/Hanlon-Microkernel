#!/usr/bin/env ruby

# this is hnl_mk_control_server.rb script
#
# it is the Microkernel Controller script, and is started as a daemon process using
# the associated hnl_mk_controller.rb script
#
#

# add the '/usr/local/lib/ruby' directory to the LOAD_PATH
# (this is where the hanlon_microkernel module files are placed by
# our Dockerfile)
$LOAD_PATH.unshift('/usr/local/lib/ruby')

require 'rubygems'
#require 'logger'
require 'net/http'
require 'open-uri'
require 'json'
require 'yaml'
require 'facter'
require 'hanlon_microkernel/logging'
require 'hanlon_microkernel/hnl_mk_registration_manager'
require 'hanlon_microkernel/hnl_mk_fact_manager'
require 'hanlon_microkernel/hnl_mk_configuration_manager'

# If an entry doesn't exist in the /etc/hosts file for the 'localhost',
# then add one that resolves to '127.0.0.1' (if the entry already exists,
# then the /etc/hosts file will remain unchanged)
%x[grep localhost /etc/hosts 2>&1 > /dev/null || sudo echo '127.0.0.1 localhost' >> /etc/hosts]

# file used to track whether or not a node has already checked in
# at least once (the first time through, this file will contain
# a true value, after that the value in this file will be false)
FIRST_CHECKIN_STATE_FILENAME = "/tmp/first_checkin.yaml"

# checks to see if this is the first checkin being made by this node
# since it was booted up
def is_first_checkin?
  first_checkin_flag = false
  File.open(FIRST_CHECKIN_STATE_FILENAME, 'r') { |file|
    first_checkin_flag = YAML::load(file)
  }
  first_checkin_flag
end

# used to set the flag in the first checkin file to false
def first_checkin_performed
  first_checkin_flag = false
  File.open(FIRST_CHECKIN_STATE_FILENAME, 'w') { |file|
    YAML::dump(first_checkin_flag, file)
  }
end

# set up a global variable that will be used in the HanlonMicrokernel::Logging mixin
# to determine where to place the log messages from this script
HNL_MK_LOG_PATH = "/var/log/hnl_mk_controller.log"

# include the HanlonMicrokernel::Logging mixin (which enables logging)
include HanlonMicrokernel::Logging

# get a reference to the Configuration Manager instance (a singleton)
config_manager = (HanlonMicrokernel::HnlMkConfigurationManager).instance

# setup the HnlMkFactManager instance (we'll use this later, in our
# HnlMkRegistrationManager constructor)
fact_manager = HanlonMicrokernel::HnlMkFactManager.new('/tmp/prev_facts.yaml')

# and set the Registration Manager to nil (will update this, below)
registration_manager = nil

# test to see if the configuration file exists
if config_manager.config_file_exists? then

  # load the Microkernel Configuration, use the parameters in that
  # configuration to setup the Microkernel Controller
  config_manager.load_current_config

  # show URI setup in the initial Microkernel configuration by the cloud-config
  logger.info "Discovered Hanlon Server at: #{config_manager.mk_uri}"

  # now, load a few items from the configuration manager, first the log
  # level that the Microkernel should use
  logger.level = config_manager.mk_log_level

  # Next, grab the URI for the Hanlon Server
  hanlon_uri = config_manager.mk_uri

  # add the "node register" entry from the configuration map to that URI
  # to get the registration URI
  registration_uri = hanlon_uri + config_manager.mk_register_path
  logger.debug "registration_uri = #{registration_uri}"

  # and add the 'node checkin' entry from the configuration map to that URI
  # to get the checkin URI
  checkin_uri = hanlon_uri + config_manager.mk_checkin_path
  logger.debug "checkin_uri = #{checkin_uri}"

  # next, the time (in secs) to sleep between iterations of the main
  # loop (below)
  checkin_interval = config_manager.mk_checkin_interval

  # next, the maximum amount of time to wait (in secs) the before starting
  # the main loop (below); a random number between zero and that amount of
  # time will be determined and used to ensure Microkernel instances are
  # offset from each other when it comes to tasks like reporting facts to
  # the Hanlon server
  checkin_skew = config_manager.mk_checkin_skew

  # this parameter defines which facts (by name) should be excluded from the
  # map that is reported during node registration
  exclude_pattern = config_manager.mk_fact_excl_pattern
  logger.debug "exclude_pattern = #{exclude_pattern}"
  registration_manager = HanlonMicrokernel::HnlMkRegistrationManager.new(registration_uri,
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

# parameters used for checkin process
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

      # Note: as of v1.1 of the Microkernel, the system is no longer identified using
      # a Microkernel-defined "hw_id" value.  Instead, the Microkernel reports an array
      # containing both the "mac_id" information (previously known as the "hw_id") and
      # a string containing the UUID (from the BIOS) to the Hanlon server and the Hanlon
      # server saves that information, along with a Hanlon-generated UUID that the system
      # will be (or is) mapped to.  The string representation of the "mac_id" option in the
      # checkin URI is constructed by the FactManager.  Currently, it includes a list of all
      # of the network interfaces that have names that look like 'eth[0-9]+', but that may
      # change down the line.
      mac_id = fact_manager.get_mac_id_array
      uuid = fact_manager.get_uuid

      # check to see if this is the first checkin or not (this flag will be true until the
      # node successfully registers for the first time after boot, after that it will be
      # false until the node is rebooted)
      is_first_checkin = is_first_checkin?

      # construct the checkin_uri_string
      checkin_uri_string = checkin_uri + "?uuid=#{uuid}&mac_id=#{mac_id}&last_state=#{idle}"
      checkin_uri_string << "&first_checkin=#{is_first_checkin}" if is_first_checkin
      logger.info "checkin_uri_string = #{checkin_uri_string}"
      uri = URI checkin_uri_string

      # then,handle the reply (could include a command that must be handled)
      response = Net::HTTP.get(uri)
      logger.debug "checkin response => #{response}"
      response_hash = JSON.parse(response)

      # if error code is 0 ()indicating a successful checkin), then process the response
      if response_hash['errcode'] == 0 then

        # get the command from the response hash (this is the action that the Hanlon
        # server would like the Microkernel Controller to take in response to the
        # checkin it just performed)
        command = response_hash['response']['command_name']

        # then trigger appropriate action based on the command in the response
        if command == "acknowledge" then
          logger.debug "Received #{command} from #{checkin_uri_string}"
          # if this is the first checkin, then we've rebooted a node quickly enough that
          # it wasn't removed from the node table; in that case we should remove
          # the first checkin flag the first time through this loop (since re-registration
          # will never be required)
          first_checkin_performed if is_first_checkin
        elsif registration_manager && command == "register" then
          logger.debug "Register command received, registering the node"
          response = registration_manager.register_node(idle)
          logger.debug "Response to registration received => #{response.inspect}"
          # if this is the first checkin to result in a successful registration,
          # then set a flag to indicate that the first checkin has been successfully
          # performed (here the 'first checkin' is represented by a checkin and
          # registration, not just a registration).  After this occurs, the
          # 'is_first_checkin' flag should be false until the node is power-cycled
          # or rebooted.
          case response
            when Net::HTTPSuccess then
              logger.debug "Checkin successful; is_first_checkin = #{is_first_checkin}"
              first_checkin_performed if is_first_checkin
            else
              logger.debug "Checkin failed; is_first_checkin = #{is_first_checkin}"
          end

        elsif command == "reboot" then
          # reboots the node, NOW...no sense in logging this since the "filesystem"
          # is all in memory and will disappear when the reboot happens
          %x[echo reboot > /tmp/cmd-channels/node-state-channel]
        elsif command == "poweroff" then
          # powers off the node, NOW...no sense in logging this since the "filesystem"
          # is all in memory and will disappear when the poweroff happens
          %x[echo poweroff > /tmp/cmd-channels/node-state-channel]
        end

        # next, check the configuration that is included in the response...
        config_map = response_hash['client_config']
        if config_map
          # if the configuration from the response is different from the current
          # Microkernel Controller configuration, then post the new configuration
          # to the local WEBrick instance (which will save it and restart this
          # Microkernel Controller so that the new configuration is picked up)
          if config_manager.mk_config_has_changed?(config_map)
            config_map_string = JSON.generate(config_map)
            uri = URI "http://localhost:2156/setMkConfig"
            header = {'Content-Type' => 'text/json'}
            http = Net::HTTP.new(uri.host, uri.port)
            logger.debug "Posting config to WEBrick server => #{config_map_string}"
            request = Net::HTTP::Post.new(uri.request_uri, header)
            request.body = config_map_string
            # Send the request
            response = http.request(request)
            # probably won't ever get here (the reboot from the WEBrick instance will intervene)
            # but, just in case...
            logger.debug "Response received back => #{response.body}"
          end
        end

      end   # end if successful checkin

    end

    # if we haven't saved the facts since we started this iteration, then we
    # need to check to see whether or not the facts have changed since our last
    # registration; if so, then we need to re-register this node
    if registration_manager && t1 > fact_manager.last_saved_timestamp then
      registration_manager.register_node_if_changed(idle)
    end

  rescue SystemExit => e
    throw e
  rescue NoMemoryError => e
    throw e
  rescue Exception => e
    logger.error("An exception occurred: #{e.message}")
    e.backtrace.each { |line| logger.debug line }
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
