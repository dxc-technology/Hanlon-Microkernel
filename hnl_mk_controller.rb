#!/usr/bin/env ruby
#
# A simple "wrapper" script that is used to daemonize the hnl_mk_control_server
# script (which represents the primary Microkernel Controller)
#
#

# add the gem directory to the LOAD_PATH
gem_dir = %x[ls -d /usr/lib/ruby/gems/*/gems].strip
$LOAD_PATH.unshift(gem_dir)

require 'rubygems'
require 'daemons'

options = {
  :ontop      => false,
  :multiple => false,
  :log_dir  => '/tmp',
  :backtrace  => true,
  :log_output => true
}

Daemons.run('/usr/local/bin/hnl_mk_control_server.rb', options)
