#!/usr/bin/env ruby

# This is the gem server, which needs to be able to start before we've installed
# any gems. As such, we can't use any razor code here, as it tries to include JSON

require 'rubygems'
require 'yaml'
require 'net/http'
require 'cgi'
require 'webrick'
require 'webrick/httpstatus'

# include the WEBrick mixin (makes this into a WEBrick server instance)
include WEBrick

# Logging - can't use razor logging here, see above
log_file = File.open "/var/log/rz_mk_gem_mirror.log", 'a+'
log = WEBrick::Log.new log_file

access_log = [
  [log_file, WEBrick::AccessLog::COMBINED_LOG_FORMAT],
]

# Now, create an HTTP Server instance (and Daemonize it)
s = HTTPServer.new(:Port => 2158, :Logger => log, :AccessLog => access_log, :ServerType => WEBrick::Daemon)

# mount our servlets as directories under our HTTP server's URI

s.mount("/gem-mirror", HTTPServlet::FileHandler, "/tmp/gem-mirror")

# setup the server to shut down if the process is shut down

trap("INT"){ s.shutdown }

# and start our server

s.start
