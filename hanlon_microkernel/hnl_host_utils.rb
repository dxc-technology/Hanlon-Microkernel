#!/usr/bin/env ruby
#
# This class defines the set of host utilities that are used by the
# Hanlon Microkernel Controller script
#
#

require 'rubygems'
require 'facter'

module HanlonMicrokernel
  class RzHostUtils

    def initialize
      @host_id = 'mk' + Facter.value('macaddress_eth0').gsub(':','')
    end

    # runs the "hostname" command in order to set the systems hostname
    # (used by the hnl_mk_controller script when setting up the system
    # during the boot process). Also modifies the contents of the
    # /etc/hosts and /etc/hostname file so that the hostname is set
    # consistently there as well
    def set_host_name
      %x[sudo hostname #{@host_id}]
      sed_in_place('/etc/hostname', "s/rancher/#{@host_id}/")
      sed_in_place('/etc/hosts', "s/127.0.0.1\tlocalhost/127.0.0.1\tlocalhost #{@host_id}/", '-r')
    end

    # replacement for 'sed -i' command on a file in our Microkernel container
    # since that command fails in an overlay filesystem; instead will make use
    # of a copy of the file in '/tmp' filesystem instead
    def sed_in_place(filename, expr, flags = '')
      basename = File.basename(filename)
      %x[sudo cp #{filename} /tmp; sudo sed #{flags} '#{expr}' /tmp/#{basename} > #{filename}; sudo rm /tmp/#{basename}]
    end

  end
end
