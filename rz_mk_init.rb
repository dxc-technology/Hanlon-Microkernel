#!/usr/bin/env ruby

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

require_relative 'rz_network_utils'
require_relative 'rz_mk_bundle_controller'

# First, install the bundles we'll need later on (this call should install
# stomp, facter, and bluepill using bundler).  Note: we are taking advantage
# of the two default values defined in the RzMkBundleController constructor
# here (that the bundle list file will be called "bundle.list" and that the
# gemfile for all of these bundles will be called "Gemfile")
bc = RzMkBundleController.new("/opt/bundles")
bc.installAllBundles

# Now that we've installed the facter bundle, need do do a bit more work
# first, determine where the facter gem's library is at (will need that later,
# when we start the MCollective daemon)

require 'rubygems'
require 'facter'
facter_root= Gem.loaded_specs['facter'].full_gem_path
facter_lib = File.join(facter_root, 'lib')
gem_root = facter_root.split(File::SEPARATOR)[0...-2].join(File::SEPARATOR)

# Next, if the facter command that it contains isn't already available in the
# /usr/local/bin directory then we need construct a link to the executable in
# the #{gem_root}/bin subdirectory...

if !File.exists?("/usr/local/bin/facter") then
  facter_exec = File.join(File.join(gem_root,"bin"),"facter")
  %x[sudo ln -s #{facter_exec} /usr/local/bin/facter]
end


# now that the bundles are installed, can require the RzHostUtils class
# (which depends on the 'facter' gem)
require_relative 'rz_host_utils'

# and start the rz_mk_controller.rb script (using the
# rz_mk_controllerd.rb script, which wraps it up
# as a daemon process)

%x[sudo /usr/local/bin/rz_mk_controllerd.rb start]

# Then, wait for the network to start
nw_is_avail = false
rz_nw_util = RzNetworkUtils.new
error_cond = rz_nw_util.wait_until_nw_avail
nw_is_avail = true if error_cond == 0

# if the network is available (there's an ethernet adapter that is up and
# has a valid IP address), then start up the MCollective agent
if nw_is_avail then

  # sleep 5 more seconds, just in case
  sleep 5

  # and proceed with startup of the network-dependent tasks
  puts "Network is available, proceeding..."

  # first, set the hostname for this host to something unique
  # (waited until now because didn't want to have eth0 not
  # available at this point)
  rz_host_util = RzHostUtils.new
  rz_host_util.set_host_name

  # and start up the MCollective daemon
  t = %x[sudo env RUBYLIB=/usr/local/lib/ruby/1.8:/usr/local/mcollective/lib:#{facter_lib} \
    mcollectived --config /usr/local/etc/mcollective/server.cfg \
    --pidfile /var/run/mcollective.pid]

elsif error_cond == RzNetworkUtils::TIMEOUT_EXCEEDED then

  puts "Maximum wait time exceeded, network not found, exiting..."
  exit(RzNetworkUtils::TIMEOUT_EXCEEDED)

elsif error_cond == RzNetworkUtils::INVALID_IP_ADDRESS then

  puts "DHCP address assignment failed, exiting..."
  exit(RzNetworkUtils::INVALID_IP_ADDRESS)

end
