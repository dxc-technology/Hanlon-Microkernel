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
# if the facter command that it contains isn't already available in the
# /usr/local/bin directory (will construct a link to the executable in the
# /usr/local/lib/ruby/gems subdirectory...there should only be one matching
# executable in that subdirectory)
if !File.exists?("/usr/local/bin/facter") then
  file_list = %x[sudo find /usr/local/lib -follow | grep facter$]
  facter_exec_pattern = /\/usr\/local\/lib\/ruby\/gems\/(\d+\.)+\d\/bin\/facter/
  file_list.split.each { |filename|
    %x[sudo ln -s #{filename} /usr/local/bin/facter] if filename =~ facter_exec_pattern
  }
end


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
  t = %x[sudo env RUBYLIB=/usr/local/lib/ruby/1.8:/usr/local/mcollective/lib \
    mcollectived --config /usr/local/etc/mcollective/server.cfg \
    --pidfile /var/run/mcollective.pid]

elsif error_cond == RzNetworkUtils::TIMEOUT_EXCEEDED then

  puts "Maximum wait time exceeded, network not found, exiting..."
  exit(RzNetworkUtils::TIMEOUT_EXCEEDED)

elsif error_cond == RzNetworkUtils::INVALID_IP_ADDRESS then

  puts "DHCP address assignment failed, exiting..."
  exit(RzNetworkUtils::INVALID_IP_ADDRESS)

end
