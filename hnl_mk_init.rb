#!/usr/bin/env ruby
#
# Used during the boot process to initialize the Microkernel
# (start up the critical services)
#
#

# add the '/usr/local/lib/ruby' directory to the LOAD_PATH
# (this is where the hanlon_microkernel module files are placed by
# our Dockerfile)
$LOAD_PATH.unshift('/usr/local/lib/ruby')

require 'yaml'
require 'hanlon_microkernel/hnl_network_utils'
require 'rubygems'
require 'facter'
require 'hanlon_microkernel/hnl_host_utils'

# Wait for the network to start
nw_is_avail = false
hnl_nw_util = HanlonMicrokernel::RzNetworkUtils.new
error_cond = hnl_nw_util.wait_until_nw_avail
nw_is_avail = true if error_cond == HanlonMicrokernel::RzNetworkUtils::SUCCESS

# if the network is available (there's an ethernet adapter that is up and
# has a valid IP address), then start up the controller scripts
if nw_is_avail then

  # sleep 5 more seconds, just in case
  sleep 5

  # and proceed with startup of the network-dependent tasks
  puts "Network is available, proceeding..."

  # first, set the hostname for this host to something unique
  # (waited until now because didn't want to have eth0 not
  # available at this point)
  hnl_host_util = HanlonMicrokernel::RzHostUtils.new
  hnl_host_util.set_host_name

  # next, start the hnl_mk_web_server and hnl_mk_controller scripts
  %x[sudo /usr/local/bin/hnl_mk_web_server.rb 2>&1 > /tmp/hnl_web_server.out]
  %x[sudo /usr/local/bin/hnl_mk_controller.rb start]

  # finally, print out the Microkernel version number (which should be in the
  # /tmp/mk_version.yaml file)
  mk_version_hash = File.open("/tmp/mk-version.yaml", 'r') { |file|
    YAML::load(file)
  }
  puts "MK Loaded: v#{mk_version_hash['mk_version']}"

elsif error_cond == HanlonMicrokernel::RzNetworkUtils::TIMEOUT_EXCEEDED then

  puts "Maximum wait time exceeded, network not found, exiting..."
  exit(HanlonMicrokernel::RzNetworkUtils::TIMEOUT_EXCEEDED)

elsif error_cond == HanlonMicrokernel::RzNetworkUtils::INVALID_IP_ADDRESS then

  puts "DHCP address assignment failed, exiting..."
  exit(HanlonMicrokernel::RzNetworkUtils::INVALID_IP_ADDRESS)

end
