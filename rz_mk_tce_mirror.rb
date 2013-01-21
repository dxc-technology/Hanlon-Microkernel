#!/usr/bin/env ruby

# this is rz_mk_control_server.rb
# it starts up a WEBrick server that can be used to control the Microkernel
# (commands to the Microkernel are invoked using Servlets running in the
# WEBrick instance)
#
#

require 'rubygems'
require 'yaml'
require 'net/http'
require 'cgi'
require 'json'
require 'webrick'
require 'webrick/httpstatus'
require 'razor_microkernel/logging'

# include the WEBrick mixin (makes this into a WEBrick server instance)
include WEBrick

# next, define our actions (as servlets)...

class TceInstallListServlet < HTTPServlet::AbstractServlet

  def do_GET(req, res)
    # create a new HTTP Response
    config = WEBrick::Config::HTTP
    extension_list = YAML::load(File.open('/tmp/tinycorelinux/tce-install-list.yaml'))
    return_str = JSON.generate(extension_list)
    logger.info "Returning JSON string '#{return_str}' to user"
    res.content_type = 'application/json'
    res.content_length = return_str.length
    res.body = return_str
    res.status = 200
  end

end

class KmodInstallListServlet < HTTPServlet::AbstractServlet

  def do_GET(req, res)
    # create a new HTTP Response
    config = WEBrick::Config::HTTP
    kmod_list = YAML::load(File.open('/tmp/tinycorelinux/kmod-install-list.yaml'))
    return_str = JSON.generate(kmod_list)
    logger.info "Returning JSON string '#{return_str}' to user"
    res.content_type = 'application/json'
    res.content_length = return_str.length
    res.body = return_str
    res.status = 200
  end

end

# set up a global variable that will be used in the RazorMicrokernel::Logging mixin
# to determine where to place the log messages from this script
RZ_MK_LOG_PATH = "/var/log/rz_mk_tce_mirror.log"

# include the RazorMicrokernel::Logging mixin (which enables logging)
include RazorMicrokernel::Logging

# Now, create an HTTP Server instance (and Daemonize it)

s = HTTPServer.new(:Port => 2157, :Logger => logger, :ServerType => WEBrick::Daemon, :BindAddress => "127.0.0.1")

# mount our servlets as directories under our HTTP server's URI

s.mount("/tinycorelinux/4.x/x86/tcz", HTTPServlet::FileHandler, "/tmp/tinycorelinux/4.x/x86/tcz")
s.mount("/tinycorelinux/tce-install-list", TceInstallListServlet)
s.mount("/tinycorelinux/kmod-install-list", KmodInstallListServlet)

# setup the server to shut down if the process is shut down

trap("INT"){ s.shutdown }

# and start out server

s.start
