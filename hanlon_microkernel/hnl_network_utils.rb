#!/usr/bin/env ruby
#
# This class defines the set of network utilities that are used by the
# Hanlon Microkernel Controller script
#
#

module HanlonMicrokernel
  class RzNetworkUtils

    # used internally
    NETWORK_MOD_SEL_PATTERN = /^(bnx2)/
    MAX_WAIT_TIME = 2 * 60    # wait for 2 minutes, max
    DEF_ETH_PREFIX = "eth"
    SUCCESS = 0

    # meant for external use
    TIMEOUT_EXCEEDED = -1
    INVALID_IP_ADDRESS = -2

    # @param eth_prefix [String]
    def initialize(eth_prefix=DEF_ETH_PREFIX)
      @eth_prefix = eth_prefix
    end

    def current_wait_time
      Time.now.to_i - @start_time
    end

    def wait_until_nw_avail

      # Set a few flags/values that will be used later on
      nic_found = false
      nic_has_ip_addr = false
      found_a_valid_ip = false
      dev_prefix = nil
      prev_attempts = 0
      wait_time = 0.0

      # and grab the start time (to use in calculating the total time elapsed)
      @start_time = Time.now.to_i

      # Start loop that will run until the network is available (or until the timeout
      # value is exceeded)

      puts "Looking for network, this is attempt ##{prev_attempts + 1}"
      begin

        if wait_time > 0.0
          # if a NIC wasn't found in the previous attempt, try reloading the
          # firmware drivers that were installed in the kernel module
          unless nic_found
            kernel_mod_list = %x[lsmod].split("\n")
            network_mod_list = kernel_mod_list.select{|elem| NETWORK_MOD_SEL_PATTERN.match(elem)}.map{|match| match.split()[0]}
            if network_mod_list.length > 0
              puts "no NICs found; reload network #{network_mod_list[0]} firmware module..."
              mod_name = network_mod_list[0]
              %x[sudo rmmod #{mod_name}; sudo modprobe #{mod_name}]
            end
          end
          # if a NIC was found in the previous attempt, but it doesn't have
          # a valid IP address, try restarting the DHCP client (to force another
          # DHCP request)
          unless nic_has_ip_addr
            puts "no valid IP addresses found; restart DHCP client..."
            %x[sudo /etc/init.d/services/dhcp stop; sudo /etc/init.d/services/dhcp start]
          end
        end

        # loop through the ifconfig entries and search one ethernet NIC that
        # has a valid IP address

        %x[ifconfig].split("\n\n").each { |entry|

          # for each entry, check for an ethernet adapter (to eliminate
          # the loopback adapter) that has been assigned an IP address
          # and is in an "UP" state

          nic_prefix_match = /(#{@eth_prefix}\d+)/.match(entry)
          dev_prefix = nil unless nic_prefix_match
          dev_prefix = nic_prefix_match[1] if nic_prefix_match

          # set a flag indicating whether or not we found a NIC with an IP address assigned to it
          this_nic_pref_matches = (dev_prefix != nil)
          nic_has_ip_addr = (this_nic_pref_matches && /inet addr:\d+\.\d+\.\d+\.\d+\s+/.match(entry) != nil)

          # and set a flag indicating whether or not we found any NICs (at least one) with the right prefix
          nic_found = this_nic_pref_matches unless nic_found

          # if we find an adapter that matches the criteria, above, then
          # check to see if it has a valid IP address and break out of the
          # inner loop (over ifconfig entries)

          if nic_has_ip_addr

            # 127.xx.xx.xx type addresses are loopback interfaces, and
            # 169.xx.xx.xx type addresses indicate that the DHCP request timed out
            # and no routable IP address was assigned to the NIC in question (even
            # though the adapter is up, it doesn't have a valid IP address assigned
            # to it); in either case it's not a "valid IP"
            found_a_valid_ip = !/inet addr:(127|169)\.\d+\.\d+\.\d+\s+/.match(entry)
            break if found_a_valid_ip

          end

        }

        # if this attempt failed, sleep for some time and try again
        unless found_a_valid_ip
          # increment the counter for the number of previous attempts made
          prev_attempts += 1
          # calculate the "wait_time" using an exponential backoff algorithm:
          #
          #      1/2 * (2**c - 1)
          #
          # Note; here the value "c" represents the number of previous attempts
          # that have been made (starting with a value of zero, it is incremented by
          # one each time an attempt is made)
          wait_time = (((1 << prev_attempts) - 1) / 2.0).round
          puts "Attempt ##{prev_attempts} failed; sleeping for #{wait_time} secs and retrying..."
          sleep(wait_time)
        end

      end until (found_a_valid_ip || current_wait_time >= MAX_WAIT_TIME)

      # Return an appropriate error condition if the timeout was exceeded or if we
      # didn't receive a valid IP address

      return(TIMEOUT_EXCEEDED) if !nic_has_ip_addr
      return(INVALID_IP_ADDRESS) if !found_a_valid_ip

      # Otherwise, return a zero "error condition" (for success)
      SUCCESS

    end

  end
end
