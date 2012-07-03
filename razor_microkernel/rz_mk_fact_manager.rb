# Used to manage the facts gathered (using Facter) in the Microkernel
#
#

require 'rubygems'
require 'facter'
require 'facter/util/ip'
require 'yaml'

module RazorMicrokernel
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

    def get_hw_id_array
      hw_id_array = []
      # get a list of the IP interfaces from Facter
      interface_array = Facter::Util::IP.get_interfaces
      # for each interface...
      interface_array.each { |interface|
        # if the name of the interface starts with the string 'eth' and is followed by
        # one or more numbers, add the MAC address for that interface to the hw_id_array
        if /^eth[0-9]+$/.match(interface)
          mac_address = Facter::Util::IP.get_interface_value(interface,'macaddress')
          hw_id_array << mac_address if mac_address
        end
      }
      hw_id_array.join('_').gsub(/:/,'')
    end

  end
end
