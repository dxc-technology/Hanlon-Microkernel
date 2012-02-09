#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'

Daemons.run('/usr/local/bin/rz_mk_controller.rb')
