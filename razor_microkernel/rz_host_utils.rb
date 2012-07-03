#!/usr/bin/env ruby
#
# This class defines the set of host utilities that are used by the
# Razor Microkernel Controller script
#
#

require 'rubygems'
require 'facter'

module RazorMicrokernel
  class RzHostUtils

    def initialize
      @host_id = 'mk' + Facter.macaddress_eth0.gsub(':','')
    end

    # runs the "hostname" command in order to set the systems hostname
    # (used by the rz_mk_controller script when setting up the system
    # during the boot process). Also modifies the contents of the
    # /etc/hosts and /etc/hostname file so that the hostname is set
    # consistently there as well
    def set_host_name
      %x[sudo hostname #{@host_id}]
      %x[sudo sed -i 's/127.0.0.1 box/127.0.0.1 #{@host_id}/' /etc/hosts]
      %x[sudo sed -i 's/box/#{@host_id}/' /etc/hostname]
    end

  end
end
