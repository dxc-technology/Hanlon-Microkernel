#!/usr/bin/env ruby
#
# Used during the boot process to initialize the Microkernel (install gems
# and start up the critical services)
#
#

require 'yaml'
require 'razor_microkernel/rz_network_utils'
require 'razor_microkernel/rz_mk_gem_controller'
require 'razor_microkernel/rz_mk_configuration_manager'

# Start the Gem mirror so we can install from it
%x[sudo /usr/local/bin/rz_mk_gem_mirror.rb 2>&1 > /tmp/rz_mk_gem_mirror.out]

# First, install the gems that we'll need later on.  Note: if the parameters
# needed to find an external mirror are not specified, we'll take advantage
# of the default values for the two input arguments to the RzMkGemController
# constructor here (since we use the "http://localhost:2158/gem-mirror" URI
# for our local gem mirror and the "gem.list" file, which contains the list
# of gems to install from that mirror, is in the "gems/gem.list" file under
# that local mirror URI)
gemController = (RazorMicrokernel::RzMkGemController).instance
mk_conf_filename = RazorMicrokernel::RzMkConfigurationManager::MK_CONF_FILE
mk_conf = YAML::load(File.open(mk_conf_filename))
gemController.gemSource = mk_conf['mk_gem_mirror_uri']
gemController.gemListURI = mk_conf['mk_gemlist_uri']
gemController.installListedGems

# Now that we've installed the facter gem, need do do a bit more work
# first, determine where the facter gem's library is at

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

# now that the gems are installed, can require the RzHostUtils class
# (which depends on the 'facter' gem)
require 'razor_microkernel/rz_host_utils'

# Then, wait for the network to start
nw_is_avail = false
rz_nw_util = RazorMicrokernel::RzNetworkUtils.new
error_cond = rz_nw_util.wait_until_nw_avail
nw_is_avail = true if error_cond == RazorMicrokernel::RzNetworkUtils::SUCCESS

# if the network is available (there's an ethernet adapter that is up and
# has a valid IP address), then start up the controller scripts
if nw_is_avail then

  # sleep 5 more seconds, just in case
  sleep 5

  # and proceed with startup of the network-dependent tasks
  puts "Network is available, proceeding..."

  # Discover the IP of the Razor server
  ip = rz_nw_util.discover_rz_server_ip
  puts "Discovered Razor Server at: #{ip}"
  y = YAML.load_file('/tmp/mk_conf.yaml')
  y["mk_uri"] = "http://#{ip}:8026"
  File.open('/tmp/mk_conf.yaml', 'w') {|f| f.write(y.to_yaml) }

  # first, set the hostname for this host to something unique
  # (waited until now because didn't want to have eth0 not
  # available at this point)
  rz_host_util = RazorMicrokernel::RzHostUtils.new
  rz_host_util.set_host_name

  # next, start the rz_mk_web_server, rz_mk_tce_mirror and rz_mk_controller scripts
  %x[sudo /usr/local/bin/rz_mk_web_server.rb 2>&1 > /tmp/rz_web_server.out]
  %x[sudo /usr/local/bin/rz_mk_tce_mirror.rb 2>&1 > /tmp/rz_mk_tce_mirror.out]
  %x[sudo /usr/local/bin/rz_mk_controller.rb start]

  # finally, print out the Microkernel version number (which should be in the
  # /tmp/mk_version.yaml file)
  mk_version_hash = File.open("/tmp/mk-version.yaml", 'r') { |file|
    YAML::load(file)
  }
  puts "MK Loaded: v#{mk_version_hash['mk_version']}"

elsif error_cond == RazorMicrokernel::RzNetworkUtils::TIMEOUT_EXCEEDED then

  puts "Maximum wait time exceeded, network not found, exiting..."
  exit(RazorMicrokernel::RzNetworkUtils::TIMEOUT_EXCEEDED)

elsif error_cond == RazorMicrokernel::RzNetworkUtils::INVALID_IP_ADDRESS then

  puts "DHCP address assignment failed, exiting..."
  exit(RazorMicrokernel::RzNetworkUtils::INVALID_IP_ADDRESS)

end
