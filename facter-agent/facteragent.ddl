# DDL file for the facter agent (defines the actions, inputs and outputs
# for this agent for the control node)
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

metadata  :name         => "Facter Agent",
          :description  => "Preliminary Facter Agent",
          :author       => "Tom McSweeney",
          :license      => "Apache v2",
          :version      => "1.0",
          :url          => "http://www.emc.com",
          :timeout      => 60

action "getall", :description => "Get facts from node using Facter" do
    display :always  # supported in 0.4.7 and newer only
 
    output :facts,
          :description => "YAML representation of Facter Hash Map",
          :display_as  => "Facts"

end
