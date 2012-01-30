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

nw_is_avail = false

rz_nw_util = RzNetworkUtils.new
error_cond = rz_nw_util.wait_until_nw_avail
nw_is_avail = true if error_cond == 0

# add services to start once the network is up here...these services will
# only run once the network is available

if nw_is_avail then

  # sleep 15 more seconds, just in case
  sleep 15

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
