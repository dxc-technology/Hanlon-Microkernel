#!/usr/bin/env ruby
#
# This class defines the set of network utilities that are used by the
# Razor Microkernel Controller script
#
#

module RazorMicrokernel
  class RzNetworkUtils

    # used internally
    MAX_WAIT_TIME = 15 * 60   # wait for 15 minutes, max
    WAIT_BETWEEN_ITER = 15    # wait 15 seconds between iterations
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

      # Set a couple of flags that will be used later on
      is_first_iter = true
      is_eth_up = false
      ip_is_valid = false

      # and grab the start time (to use in calculating the total time elapsed)
      @start_time = Time.now.to_i

      # Start loop that will run until the network is available (or until the timeout
      # value is exceeded)

      begin

        # if it's not hte first time through the loop, sleep, otherwise reset the
        # is_first_iter flag to false (it shouldn't be true the next time through)

        !is_first_iter ? sleep(WAIT_BETWEEN_ITER) : is_first_iter = false

        # loop through the entries in the output of the "ifconfig" command
        # (under TCL, these entries are separated by a double-newline, so
        # split the output of the "ifconfig" command on that string)

        %x[ifconfig].split("\n\n").each { |entry|

          # for each entry, check for an ethernet adapter (to eliminate
          # the loopback adapter) that has been assigned an IP address
          # and is in an "UP" state

          is_eth_up = (/#{@eth_prefix}\d+/.match(entry) &&
              /inet addr:\d+\.\d+\.\d+\.\d+\s+/.match(entry) &&
              /UP/.match(entry))

          # if we find an adapter that matches the criteria, above, then
          # check to see if it has a valid IP address and break out of the
          # inner loop (over ifconfig entries)

          if is_eth_up

            # 169.xx.xx.xx type addresses indicate that the DHCP request failed
            # to assign an address to the NIC in question (even though the adapter
            # is up, it doesn't have a valid IP address assigned to it)

            ip_is_valid = !/inet addr:169\.\d+\.\d+\.\d+\s+/.match(entry)
            break

          end

        }

      end until (is_eth_up || current_wait_time >= MAX_WAIT_TIME)

      # Return an appropriate error condition if the timeout was exceeded or if we
      # didn't receive a valid IP address

      return(TIMEOUT_EXCEEDED) if !is_eth_up
      return(INVALID_IP_ADDRESS) if !ip_is_valid

      # Otherwise, return a zero "error condition" (for success)
      SUCCESS

    end

  end
end
