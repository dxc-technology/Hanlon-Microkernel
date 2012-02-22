#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'

options = {
  :ontop      => false,
  :multiple => false,
  :log_dir  => '/tmp',
  :backtrace  => true,
  :log_output => true
}

Daemons.run('rz_mk_control_server.rb', options)
