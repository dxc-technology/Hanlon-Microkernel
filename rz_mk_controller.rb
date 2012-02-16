#!/usr/bin/env ruby

# this is rz_mk_controller.rb
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

require_relative 'fact_manager'
require 'logger'
require 'net/http'
require 'cgi'
require 'json'
require 'webrick'
include WEBrick

# setup a logger for our HTTP server...

mylog = Logger.new('/var/log/rz_mk_controller.log', 5, 1024*1024)
# mylog = Logger.new('/var/log/rz_mk_controller.log', 5, 'daily')
mylog.level = Logger::DEBUG

# can format the datetime for the messages this way
# mylog.datetime_format = "%Y-%m-%d %H:%M:%S"

# OR, can change the overall format this way (note how strftime is used
# within the defined proc to reformat the datetime argument)
mylog.formatter = proc do |severity, datetime, progname, msg|
  "(#{severity}) [#{datetime.strftime("%Y-%m-%d %H:%M:%S")}]: #{msg}\n"
end

# next, define our actions (as servlets)...for now we've just got one (registration)

class RegistrationServlet < HTTPServlet::AbstractServlet

  def initialize(server, logger)
    super(server)
    @logger = logger
    # define a few parameter we'll use later
    @prev_facts_file = '/tmp/facterOut.yaml'
    @prev_registration_file = '/tmp/prevRegistrationURI.yaml'
    @default_state = "idle"

    exclude_pattern = /(^uptime.*$)|(^memory.*$)/

    # and create a new instance of the FactManager class (will use this
    # later to interact with the Facter class and retrieve system facts)
    @fact_manager = FactManager.new(@prev_facts_file, exclude_pattern)

  end

  def registration_uri_changed?(registration_uri)
    return true if !File.exists?(@prev_registration_file)
    prev_registration_uri = ""
    File.open(@prev_registration_file, 'r') { |file|
      prev_registration_uri = YAML::load(file)
    }
    return (registration_uri != prev_registration_uri)
  end

  def save_uri_as_previous(registration_uri)
    File.open(@prev_registration_file, 'w') { |file|
      YAML::dump(registration_uri, file)
    }
  end

  def do_POST(req, res)
    # get the registration URI from the request body; it should be included in
    # the body in the form of a string that looks something like the following:
    #
    #     "registrationURI=<registration_uri_val>"
    #
    # where the registration_uri_val is a CGI-escaped version of the URI
    # that we should use for registration
    registration_uri = CGI::unescape(req.body.split("=")[1])
    @logger.debug("received URI '#{registration_uri}' from registration agent")
    fact_map_changed = @fact_manager.facts_have_changed?
    # if the registration_uri has changed, then we need to report new facts regardless
    # of whether or not our current state has been reported already
    fact_map_changed = true if registration_uri_changed?(registration_uri)
    if fact_map_changed
      @fact_manager.save_facts_as_prev
      fact_map = @fact_manager.fact_map
      json_hash = {}
      json_hash["@attributes_hash"] = @fact_manager.fact_map
      json_string = JSON.generate(json_hash)
      uri = URI "#{registration_uri}/#{fact_map[:hostname]}/#{@default_state}"
      @logger.debug("factMap changed, send new factMap to '" + uri.to_s +
                      "' => " + json_string)
      # post the new factMap to the server that should be listening at the registration URI
      response = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      # and construct the response back to the registration agent
      res['Content-Type'] = response['Content-Type']
      res.body = response.body
      # finally, if are debugging the server, output the body (as a string) into the log file
      @logger.debug(response.body)
    else
      res['Content-Type'] = "text/plain"
      res.body = "factMap unchanged, no update required"
      @logger.debug("factMap unchanged, no update required")
    end
    save_uri_as_previous(registration_uri)
  end
  
end

# Now, create an HTTP Server instance (and Daemonize it)

s = HTTPServer.new(:Port => 2156, :ServerType => WEBrick::Daemon)

# mount our servlets as directories under our HTTP server's URI

s.mount("/registration", RegistrationServlet, mylog)

# setup the server to shut down if the process is shut down

trap("INT"){ s.shutdown }

# and start out server

s.start
