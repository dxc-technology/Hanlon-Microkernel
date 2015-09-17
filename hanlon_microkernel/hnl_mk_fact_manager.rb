# Used to manage the facts gathered (using Facter) in the Microkernel
#
#

require 'rubygems'
require 'facter'
require 'facter/util/ip'
require 'yaml'

module HanlonMicrokernel
  class HnlMkFactManager

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

    def get_uuid_broken
      # we've seen multi-line output from dmidecode on some systems,
      # so parse the result of the `sudo dmidecode -s system-uuid`
      # command and assume the last line is the UUID
      cmd_output = %x[sudo dmidecode -s system-uuid].chomp
      cmd_output.split("\n")[-1]
    end

    def get_uuid
      # switched from using the output of a dmidecode command (above)
      # to using the output of a lshw command to determine the SMBIOS
      # UUID for a node (since the output of a 'dmidecode -s system-uuid'
      # command has been found not to be the same as the SMBIOS UUID value
      # returned by the {uuid} directive in an iPXE boot script on
      # some systems...i.e. on some VMware virtual machines)
      %x[sudo lshw | grep -i uuid].split.select { |x| /^UUID/.match(x.upcase) }[0].split('=')[-1]
    end

  end
end
