#!/usr/bin/env ruby

# this is rz_mk_control_server.rb script
#
# it is the Microkernel Controller script, and is started as a daemon process using
# the associated rz_mk_controller.rb script
#
#

require 'rubygems'
#require 'logger'
require 'net/http'
require 'open-uri'
require 'json'
require 'yaml'
require 'facter'
require 'razor_microkernel/logging'
require 'razor_microkernel/rz_mk_registration_manager'
require 'razor_microkernel/rz_mk_fact_manager'
require 'razor_microkernel/rz_mk_configuration_manager'
require 'razor_microkernel/rz_mk_kernel_module_manager'
require 'razor_microkernel/rz_mk_gem_controller'

# load gems in the list available at #{mk_gemlist_uri} from the gem mirror
# at #{mk_gem_mirror_uri} into the Microkernel (Note; only gems that do not
# exist yet or gems who's latest version available from the stated gem mirror
# will be installed; existing versions of these gems will not be reinstalled
# by this method)
def load_gems(mk_gem_mirror_uri, mk_gemlist_uri)
  logger.debug("reloading gems from #{mk_gem_mirror_uri} using list at #{mk_gemlist_uri}")
  gemController = (RazorMicrokernel::RzMkGemController).instance
  gemController.gemSource = mk_gem_mirror_uri
  gemController.gemListURI = mk_gemlist_uri
  gemController.installListedGems
end

# this method is used to load a list of Tiny Core Linux extensions
# as the Microkernel Controller is starting up (or restarting).
# It loads the extensions listed in the YAML file at the tcl_ext_list_uri
# from the mirror at the tcl_ext_mirror_uri)
# @param [URI] tcl_ext_list_uri  a URI that points to a YAML file containing
# the array of extensions that should be loaded (by name; eg. bash.tcz)
# @param [URI] tcl_ext_mirror_uri  a URI that points to the location of a
# mirror containing the extensions to install
# @param [Object] force_reinstall  a flag indicating whether or not existing
# extensions (those already installed) should be overwritten with new versions
# from the mirror (defaults to false, which skips the installation of any
# extensions that are already installed)
def load_tcl_extensions(tce_install_list_uri, tce_mirror_uri, force_reinstall = false)

  # get the URI from the config that will return the list of TCL extensions
  # that we should load, if it doesn't exist, then just return (because we
  # don't have any extensions to load)
  return if !tce_install_list_uri || (tce_install_list_uri =~ URI::regexp).nil?

  # and get the TCE mirror URI from the config, if it doesn't exist, then
  # we just return (because we don't know where to get the extensions from)
  return if !tce_mirror_uri || (tce_mirror_uri =~ URI::regexp).nil?

  # modify the /opt/tcemirror file (so that it uses the mirror given in the
  # configuration we just received from the Razor server)
  File.open('/opt/tcemirror', 'w') { |file|
    file.puts tce_mirror_uri
  }

  # get a list of the Tiny Core Extensions that are already installed in the
  # the system; will use this list to determine whether or not an extension
  # should be loaded (we won't load an extension that is already installed)
  installed_extensions = %x[tce-status -i].split("\n")

  # get the list of 'TCL Extensions' that should be installed (these will)
  # be obtained from a local 'mirror' containing the appropriate 'tcz' files)
  begin
    # load the list of extensions to install from the URI
    install_list_uri = URI.parse(tce_install_list_uri)
    tce_install_list = []
    begin
      tce_install_list = JSON::parse(install_list_uri.read)
      logger.debug("received a TCE install list of '#{tce_install_list.inspect}'")
    rescue SystemExit => e
      throw e
    rescue NoMemoryError => e
      throw e
    rescue Exception => e
      logger.debug("error while reading from '#{install_list_uri}' => #{e.message}")
      return
    end
    logger.debug("TCE install list: '#{tce_install_list.inspect}'")

    # for each extension on that list, load that extension (using the 'tce-load' command)
    has_kernel_modules = false
    tce_install_list.each { |extension|
      # if it's in the list of installed extensions, then skip it
      next if !force_reinstall && installed_extensions.include?(extension.gsub(/.tcz$/,''))
      logger.debug "loading #{extension}"
      t = %x[sudo -u tc tce-load -iw #{extension}]
    }

    # and load the kernel modules (if any), first get a reference to the Configuration
    # Manager instance (a singleton)
    kernel_mod_manager = (RazorMicrokernel::RzMkKernelModuleManager).instance
    # and then load the modules
    kernel_mod_manager.load_kernel_modules

  rescue SystemExit => e
    throw e
  rescue NoMemoryError => e
    throw e
  rescue Exception => e
    logger.error e.message
    e.backtrace.each { |line| logger.debug line }
  end

end

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

  # "load" the appropriate gems into the Microkernel
  load_gems(config_manager.mk_gem_mirror_uri, config_manager.mk_gemlist_uri)

  # and load the TCL extensions from the configuration file (if any exist)
  load_tcl_extensions(config_manager.mk_tce_install_list_uri, config_manager.mk_tce_mirror_uri)

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

      # Note: as of v0.7.0.0 of the Microkernel, the system is no longer identified using
      # a Microkernel-defined UUID value.  Instead, the Microkernel reports an array
      # containing "hw_id" information to the Razor server and the Razor server uses that
      # information to construct the UUID that the system will be (or is) mapped to.
      # The array passed through this "hw_id" key in the JSON hash is constructed by the
      # FactManager.  Currently, it includes a list of all of the network interfaces that
      # have names that look like 'eth[0-9]+', but that may change down the line.
      hw_id = fact_manager.get_hw_id_array

      # check to see if this is the first checkin or not (this flag will be true until the
      # node successfully registers for the first time after boot, after that it will be
      # false until the node is rebooted)
      is_first_checkin = is_first_checkin?

      # construct the checkin_uri_string
      checkin_uri_string = checkin_uri + "?hw_id=#{hw_id}&last_state=#{idle}"
      checkin_uri_string << "&first_checkin=#{is_first_checkin}" if is_first_checkin
      logger.info "checkin_uri_string = #{checkin_uri_string}"
      uri = URI checkin_uri_string

      # then,handle the reply (could include a command that must be handled)
      response = Net::HTTP.get(uri)
      logger.debug "checkin response => #{response}"
      response_hash = JSON.parse(response)

      # if error code is 0 ()indicating a successful checkin), then process the response
      if response_hash['errcode'] == 0 then

        # get the command from the response hash (this is the action that the Razor
        # server would like the Microkernel Controller to take in response to the
        # checkin it just performed)
        command = response_hash['response']['command_name']

        # then trigger appropriate action based on the command in the response
        if command == "acknowledge" then
          logger.debug "Received #{command} from #{checkin_uri_string}"
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
          %x[sudo reboot now]
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
            logger.debug "Posting config to WEBrick server => #{config_map_string}"
            uri = URI "http://localhost:2156/setMkConfig"
            res = Net::HTTP.post_form(uri, config_map_string)
            # probably won't ever get here (the reboot from the WEBrick instance will intervene)
            # but, just in case...
            logger.debug "Response received back => #{res.body}"
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
