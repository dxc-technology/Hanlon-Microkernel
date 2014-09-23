# Used to manage the facts gathered (using Facter) in the Microkernel
#
#

require 'rubygems'
require 'facter'
require 'facter/util/ip'
require 'yaml'

module HanlonMicrokernel
  class RzMkFactManager

    attr_accessor :prev_facts_filename
    attr_reader :last_saved_timestamp

    def initialize(prev_facts_filename)
      @prev_facts_filename = prev_facts_filename
      @last_saved_timestamp = Time.at(0)
    end

    def facts_have_changed?(current_fact_map)
      # compare the existing facts with those previously saved to the YAML file
      fact_map_changed = false
      if File.exists?(@prev_facts_filename)
        old_fact_map = nil
        File.open(@prev_facts_filename, 'r') { |file|
          old_fact_map = YAML::load(file)
        }
        return (current_fact_map != old_fact_map)
      end
      # since file doesn't exist, the facts have changed (by definition)
      return true
    end

    def save_facts_as_prev(current_fact_map)
      File.open(@prev_facts_filename, 'w') { |file|
        YAML::dump(current_fact_map, file)
      }
      @last_saved_timestamp = Time.now
    end

    def get_mac_id_array
      mac_id_array = []
      # get a list of the IP interfaces from Facter
      interface_array = Facter::Util::IP.get_interfaces
      # for each interface...
      interface_array.each { |interface|
        # if the name of the interface starts with the string 'eth' and is followed by
        # one or more numbers, add the MAC address for that interface to the mac_id_array
        if /^eth[0-9]+$/.match(interface)
          mac_address = Facter::Util::IP.get_interface_value(interface,'macaddress')
          mac_id_array << mac_address if mac_address
        end
      }
      mac_id_array.join('_').gsub(/:/,'')
    end

    def get_uuid
      # loop through output of 'lshw -c system' command
      %x[sudo lshw -c system].split("/n").each { |line|
        # check for line that includes the configuration (which has the
        # uuid value embedded in it)
        config_line_val = /^[ ]+configuration:\s+(.+)/.match(line)
        if config_line_val && config_line_val[1]
          # if got this far, then split the match into elements, each
          # of which will look like "name=value"; then look for the
          # element who's 'name' is 'uuid'
          config_line_val[1].split.each { |elem|
            uuid_elem_match = /^uuid=(.+)$/.match(elem)
            if uuid_elem_match
              # if got this far, we've found a match
              return uuid_elem_match[1]
            end
          }
        end
      }
      # if we got to here, no uuid was found, so return an empty string
      ''
    end

  end
end
