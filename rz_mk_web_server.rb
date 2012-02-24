#!/usr/bin/env ruby

# this is rz_mk_control_server.rb
# it starts up a WEBrick server that can be used to control the Microkernel
# (commands to the Microkernel are invoked using Servlets running in the
# WEBrick instance)
#
# @author Tom McSweeney

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

require 'rubygems'
require 'logger'
require 'net/http'
require 'cgi'
require 'json'
require 'yaml'
require 'webrick'
include WEBrick

# setup a logger for our HTTP server...

logger = Logger.new('/var/log/rz_mk_web_server.log', 5, 1024*1024)
logger.level = Logger::DEBUG
logger.formatter = proc do |severity, datetime, progname, msg|
  "(#{severity}) [#{datetime.strftime("%Y-%m-%d %H:%M:%S")}]: #{msg}\n"
end

# define YAML file to use for serialization of the Microkernel configuration

mk_config_file = '/tmp/mk_conf.yaml'

# next, define our actions (as servlets)...for now we have one (used to
# save the Microkernel Configuration that is received from the MCollective
# Configuration Agent)

class MKConfigServlet < HTTPServlet::AbstractServlet

  def initialize(server, logger, mk_config_file)
    super(server)
    @logger = logger
    @mk_config_file = mk_config_file
  end

  def mk_config_has_changed?(new_mk_config_map)
    return true if !File.exists?(@mk_config_file)
    @logger.debug("File exists; check to see if the config has changed")
    old_mk_config_map = YAML::load(File.open(@mk_config_file, 'r'))
    return_val = old_mk_config_map != new_mk_config_map
    @logger.debug("mk_config_has_changed? => #{return_val}")
    return old_mk_config_map != new_mk_config_map
  end

  def save_mk_config(mk_config_map)
    File.open(@mk_config_file, 'w') { |file|
      YAML::dump(mk_config_map, file)
    }
  end

  def do_POST(req, res)
    # get the Razor URI from the request body; it should be included in
    # the body in the form of a string that looks something like the following:
    #
    #     "razorURI=<razor_uri_val>"
    #
    # where the razor_uri_val is a CGI-escaped version of the URI used by the
    # Razor server.  The "Registration Path" (from the uri_map, above) is added
    # to this Razor URI value in order to form the "registration_uri"
    json_string = CGI.unescape(req.body)
    len = json_string.length
    @logger.debug("CGI.unescapedHTML = #{json_string[0,len-1]}")
    config_map = JSON.parse(json_string[0,len-1])
    # create a new HTTP Response
    config = WEBrick::Config::HTTP
    resp = WEBrick::HTTPResponse.new(config)
    if !mk_config_has_changed?(config_map) then
      resp['Content-Type'] = 'json/application'
      return_msg = 'Configuration unchanged; no update'
      resp['message'] = JSON.generate({'json_received' => config_map,
                                       'message' => return_msg })
      @logger.debug("#{return_msg}...")
    else
      save_mk_config(config_map)
      @logger.debug("Config changed, restart the controller...")
      %x[sudo /usr/local/bin/rz_mk_controller.rb restart]
      return_msg = 'New configuration saved, Microkernel Controller restarted'
      resp['Content-Type'] = 'text/plain'
      resp['message'] = return_msg
      @logger.debug("#{return_msg}...")
    end
  end

end

# Now, create an HTTP Server instance (and Daemonize it)

s = HTTPServer.new(:Port => 2156, :ServerType => WEBrick::Daemon)

# mount our servlets as directories under our HTTP server's URI

s.mount("/setMkConfig", MKConfigServlet, logger, mk_config_file)

# setup the server to shut down if the process is shut down

trap("INT"){ s.shutdown }

# and start out server

s.start
