# The facter agent (hosted on the managed nodes, can be used to gather facts
# remotely using MCollective)
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

require 'rubygems'
require 'facter'
require 'yaml'

module MCollective
  module Agent
    class Facteragent<RPC::Agent
      metadata  :name        => "Facter Agent",
                :description => "Preliminary Facter Agent",
                :author      => "Tom McSweeney",
                :license     => "Apache v2",
                :version     => "1.0",
                :url         => "http://www.emc.com",
                :timeout     => 60

      action "getall" do
        # return the facts gathered by Facter (as a YAML-formatted string)
        factMap = Hash.new
	Facter.loadfacts
        Facter.each { |fact, value|
          factMap[fact.to_sym] = value
        }
        reply[:facts] = YAML.dump(factMap)
      end
      
    end
  end
end
