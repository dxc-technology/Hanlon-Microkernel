#!/usr/bin/env ruby

eth_prefix = "eth"
max_wait_time = 15 * 60   # wait for 15 minutes, max
current_wait_time = 0
wait_between_iter = 15    # wait 15 seconds between iterations

# Set a couple of flags that will be used later on
is_first_iter = true
is_eth_up = false;
ip_is_valid = false;

# Start loop that will run until the network is available (or until the timeout
# value is exceeded)
begin
  if !is_first_iter then
    # skip this step, the first time through the loop
    # puts "Network is not up yet, sleeping #{wait_between_iter} seconds..."
    sleep wait_between_iter
    current_wait_time += wait_between_iter
  else
    # it's the first time through the loop, so set the flag
    # to false (won't be the first time after this iteration)
    is_first_iter = false
  end

  # loop through the entries in the output of the "ifconfig" command
  # (under TCL, these entries are separated by a double-newline, so
  # split the output of the "ifconfig" command on that string)
  entries = %x[ifconfig].split("\n\n").each { |entry|
    # for each entry, check for an ethernet adapter (to eliminate
    # the loopback adapter) that has been assigned an IP address
    # and is in an "UP" state
    is_eth_up = (/#{eth_prefix}\d+/.match(entry) &&
        /inet addr:\d+\.\d+\.\d+\.\d+\s+/.match(entry) &&
        /UP/.match(entry))
    # if we find an adapter that matches the criteria, above, then
    # check to see if it has a valid IP address and break out of the
    # inner loop (over ifconfig entries)
    if is_eth_up then
      # 169.xx.xx.xx type addresses indicate that the DHCP request failed
      # to assign an address to the NIC in question (even though the adapter
      # is up, it doesn't have a valid IP address assigned to it)
      ip_is_valid = !/inet addr:169\.\d+\.\d+\.\d+\s+/.match(entry)
      break
    end
  }

end until (is_eth_up || current_wait_time >= max_wait_time)

# Provide some diagnostic output if we are about to exit the loop
if is_eth_up && ip_is_valid then
  puts "Network is available, proceeding..."
elsif !is_eth_up then
  puts "Maximum wait time exceeded, network not found, exiting..."
  exit(-1)
else
  puts "DHCP address assignment failed, exiting..."
  exit(-2)
end

# add services to start once the network is up here...these services will
# only run once the network is available
# t = %x[sudo env RUBYLIB=/usr/local/lib/ruby/1.8:/usr/local/mcollective/lib mcollectived --config /usr/local/etc/mcollective/server.cfg --pidfile /var/run/mcollective.pid]
