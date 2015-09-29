# Gathers hardware-related facts from the underlying system (used by the
# hnl_mk_registration_manager to gather these sorts of facts in order to
# supplement the facts gathered using Facter during the node registration
# process)
#
#

# add the '/usr/local/lib/ruby' directory to the LOAD_PATH
# (this is where the hanlon_microkernel module files are placed by
# our Dockerfile)
$LOAD_PATH.unshift('/usr/local/lib/ruby')

require 'singleton'
require 'json'
require 'hanlon_microkernel/logging'

# set up a global variable that will be used in the HanlonMicrokernel::Logging mixin
# to determine where to place the log messages from this script (will be combined
# with the other log messages for the Hanlon Microkernel Controller)
HNL_MK_LOG_PATH = "/var/log/hnl_mk_controller.log"

module HanlonMicrokernel
  class HnlMkHardwareFacter

    include Singleton

    # include the HanlonMicrokernel::Logging mixin (which enables logging)
    include HanlonMicrokernel::Logging

    # used by the HnlMkRegistrationManager class to add facts extracted from a set of
    # "lscpu" and "lshw" system calls to the input "facts_map" (which is assumed to
    # be a hash_map)
    # @param [Hash] facts_map
    def add_facts_to_map!(facts_map, mk_fct_excl_pattern)
      logger.debug("before...#{facts_map.inspect}")
      # check type of virtualization used (if any); must disable 'dmi' for KVM
      # virtual machines (see Hanlon issue #297)
      virtual_type = Facter.value('virtual')
      lshw_cmd =  (virtual_type && virtual_type == 'kvm') ? 'lshw -disable dmi' : 'lshw'
      begin
        # add the facts that result from running the "lscpu" command
        lscpu_facts_str = %x[lscpu]
        hash_map = lscpu_output_to_hash(lscpu_facts_str, ":")
        key = "mk_hw_lscpu_hash_json_str"
        facts_map[key.to_sym] = JSON.generate(hash_map) unless mk_fct_excl_pattern &&
            mk_fct_excl_pattern.match(key)
        fields_to_include = ["Architecture", "CPU_op-mode(s)", "Byte_Order",
                             "CPU_socket(s)", "Vendor_ID", "CPU_family",
                             "Model", "Stepping", "CPU_MHz", "BogoMIPS",
                             "Virtualization", "L1d_cache", "L1i_cache",
                             "L2_cache", "L3_cache"]
        add_flattened_hash_to_facts!(hash_map, facts_map, "mk_hw_lscpu", fields_to_include)

        # and add the facts that result from running a few "lshw" commands...first,
        # add the bus information
        lshw_c_bus_str = %x[sudo #{lshw_cmd} -c bus 2> /dev/null]
        hash_map = lshw_output_to_hash(lshw_c_bus_str, ":")
        add_hash_to_facts!(hash_map, facts_map, mk_fct_excl_pattern, "mk_hw_bus")
        # and add a set of facts from this bus information as top-level facts in the
        # facts_map so that we can use them later to tag nodes
        fields_to_include = ["description", "product", "vendor", "version", "serial", "physical_id"]
        add_flattened_hash_to_facts!(hash_map["core"], facts_map, "mk_hw_bus", fields_to_include)

        # next, the memory information (including firmware, system memory, and caches)
        lshw_c_memory_str = %x[sudo #{lshw_cmd} -c memory 2> /dev/null]
        hash_map = lshw_output_to_hash(lshw_c_memory_str, ":")
        add_hash_to_facts!(hash_map, facts_map, mk_fct_excl_pattern, "mk_hw_mem", /cache_array/)
        # and add a set of facts from this memory information as top-level facts in the
        # facts_map so that we can use them later to tag nodes
        fields_to_include = ["description", "vendor", "physical_id", "version",
                             "date", "size", "capabilities", "capacity"]
        add_flattened_hash_to_facts!(hash_map["firmware"], facts_map,
                                     "mk_hw_fw", fields_to_include)
        fields_to_include = ["description", "physical_id", "slot", "size"]
        add_flattened_hash_to_facts!(hash_map["memory"], facts_map,
                                     "mk_hw_mem", fields_to_include)
        # grab the same meta-data from the slots that aren't empty from the "bank_array"
        # field of our hash_map
        non_empty_slot_info = hash_map["bank_array"].select{ |slot_entry| slot_entry['size'] }
        add_flattened_array_to_facts!(non_empty_slot_info, facts_map,
                                     "mk_hw_mem_slot", fields_to_include)

        # next, the disk information (number of disks, sizes, etc.)
        lshw_c_disk_str = %x[sudo #{lshw_cmd} -c disk 2> /dev/null]
        hash_map = lshw_output_to_hash(lshw_c_disk_str, ":")
        add_hash_to_facts!(hash_map, facts_map, mk_fct_excl_pattern, "mk_hw_disk")
        # and add a set of facts from the array of disk information as top-level facts in the
        # facts_map so that we can use them later to tag nodes
        fields_to_include = ["description", "product", "physical_id", "bus_info",
                             "logical_name", "version", "serial", "size",
                             "configuration"]
        disk_array = nil
        if hash_map["disk_array"]
          disk_array = hash_map["disk_array"]
        elsif hash_map["disk"]
          disk_array = []
          disk_array << hash_map["disk"]
        end
        add_flattened_array_to_facts!(disk_array, facts_map, "mk_hw_disk", fields_to_include) if disk_array

        # next, the processor information
        lshw_c_processor_str = %x[sudo #{lshw_cmd} -c processor 2> /dev/null]
        hash_map = lshw_output_to_hash(lshw_c_processor_str, ":")
        add_hash_to_facts!(hash_map, facts_map, mk_fct_excl_pattern, "mk_hw_proc")
        # and add a set of facts from the array of processor information as top-level facts in the
        # facts_map so that we can use them later to tag nodes
        fields_to_include = ["description", "product", "vendor", "physical_id",
                             "bus_info", "version", "serial", "slot", "size",
                             "capacity", "width", "clock", "capabilities",
                             "configuration"]
        add_flattened_array_to_facts!(hash_map["cpu_array"], facts_map,
                                      "mk_hw_cpu", fields_to_include)

        # and finally, the network information
        lshw_c_network_str = %x[sudo #{lshw_cmd} -c network 2> /dev/null]
        hash_map = lshw_output_to_hash(lshw_c_network_str, ":")
        add_hash_to_facts!(hash_map, facts_map, mk_fct_excl_pattern, "mk_hw_nw")
        # and add a set of facts from the array of network information as top-level facts in the
        # facts_map so that we can use them later to tag nodes
        fields_to_include = ["description", "physical_id", "bus_info",
                             "logical_name", "version", "serial", "size",
                             "capacity", "width", "clock", "capabilities",
                             "configuration"]
        add_flattened_array_to_facts!(hash_map["network_array"], facts_map,
                                      "mk_hw_nic", fields_to_include)

        # add the facts that result from running the "ipmitool mc info" command
        ipmitool_bmc_info_str = %x[sudo ipmitool bmc info 2> /dev/null]
        # assume that if there was a non-zero exit status, it's because there is no IPMI system
        # in place on this node...skip the rest of the IPMI-related facts
        unless $?.exitstatus != 0 && ipmitool_bmc_info_str.empty?
          hash_map = ipmitool_output_to_hash(ipmitool_bmc_info_str, ":", :bmc_info)
          logger.debug("after ipmitool_output_to_hash...#{hash_map.inspect}")
          fields_to_include = ["Device_ID", "Device_Revision", "Firmware_Revision",
                               "IPMI_Version", "Manufacturer_ID", "Manufacturer_Name",
                               "Product_ID", "Product_Name", "Device_Available",
                               "Provides_Device_SDRs"]
          add_flattened_hash_to_facts!(hash_map, facts_map, "mk_ipmi", fields_to_include)
          # add the facts that result from running the "ipmitool lan print" command
          ipmitool_lan_print_str = %x[sudo ipmitool lan print 2> /dev/null]
          unless $?.exitstatus != 0 && ipmitool_lan_print_str.empty?
            hash_map = ipmitool_output_to_hash(ipmitool_lan_print_str, ":", :lan_print)
            logger.debug("after ipmitool_output_to_hash...#{hash_map.inspect}")
            fields_to_include = ["IP_Address_Source", "IP_Address",
                                 "Subnet_Mask", "MAC_Address",
                                 "SNMP_Community_String", "IP_Header",
                                 "BMC_ARP_Control", "Gratuitous_ARP_Intrvl",
                                 "Default_Gateway_IP", "Default_Gateway_MAC",
                                 "Backup_Gateway_IP", "Backup_Gateway_MAC",
                                 "8021q_VLAN_ID", "8021q_VLAN_Priority"]
            add_flattened_hash_to_facts!(hash_map, facts_map, "mk_ipmi", fields_to_include)
          end
          # add the facts that result from running the "ipmitool fru print" command
          ipmitool_fru_print_str = %x[sudo ipmitool fru print 2> /dev/null]
          unless $?.exitstatus != 0 && ipmitool_fru_print_str.empty?
            hash_map = ipmitool_output_to_hash(ipmitool_fru_print_str, ":", :fru_print)
            logger.debug("after ipmitool_output_to_hash...#{hash_map.inspect}")
            fields_to_include = ['^fru_\d+_Chassis_Type$', '^fru_\d+_Chassis_Part_Number$', '^fru_\d+_Chassis_Serial$',
                                 '^fru_\d+_Board_Mfg_Date$', '^fru_\d+_Board_Mfg$', '^fru_\d+_Board_Product$',
                                 '^fru_\d+_Board_Serial$', '^fru_\d+_Board_Part_Number$']
            add_flattened_hash_to_facts!(hash_map, facts_map, "mk_ipmi", fields_to_include, :like)
          end
        end

      rescue SystemExit => e
        throw e
      rescue NoMemoryError => e
        throw e
      rescue Exception => e
        logger.error(e.backtrace.join("\n\t"))
      end

      # finally, sweep through the facts_map and remove any offending keys
      # (remapping those values to new keys that don't contain any offending
      # characters)
      clean_fact_map_keys!(facts_map)
      logger.debug("after...#{facts_map.inspect}")

    end

    private

    # used by the "add_facts_to_map!" method (above) to supplement the contents
    # of the input "facts_map" with top-level name/value pairs contained in the
    # input "hash_map"
    # @param [Hash] hash_map  The Hash containing the facts that should be added
    # @param [Hash] facts_map  The Hash to those facts should be added to
    # @param [Regexp] mk_fact_excl_pattern  A pattern that, if matched by any key (even
    # after that key has been modified to indicate that it is a JSON string) will keep that
    # key/value pair from being added to the facts_map; this key is used to filter out
    # individual key/value pairs
    # @param [String] prefix  A prefix that should be added to each (top-level)
    # key in the hash_map before that name/value pair is added to the facts_map
    # (used to make the keys for the elements added to the facts_map unique)
    # @param [Regexp] field_exclude_pattern  A pattern that, if matched by a key, will
    # result in that key/value pair not being added the facts_map; this field is used
    # to block entire sets of facts from being added to the facts_map
    def add_hash_to_facts!(hash_map, facts_map, mk_fact_excl_pattern, prefix,
                           field_exclude_pattern = nil)
      return unless hash_map
      hash_map.each {|key, value|
        key = prefix + '_' + key
        next if (field_exclude_pattern && field_exclude_pattern.match(key)) ||
            (mk_fact_excl_pattern && mk_fact_excl_pattern.match(key))
        unless value.is_a?(String)
          key << "_json_str"
          next if mk_fact_excl_pattern && mk_fact_excl_pattern.match(key)
          facts_map[key.to_sym] = JSON.generate(value)
          next
        end
        facts_map[key.to_sym] = value
      }
    end

    # used by the add_facts_to_map! method (above) to flatten out a hash map and add a
    # selected set of key/value pairs to the facts_map
    # @param [Array] hash_map  The Hash map that contains the name/value pairs that
    # should be added to the facts_map
    # @param [Hash] facts_map  The Hash map to supplement with facts from the hash_map
    # @param [String] prefix  The prefix to use to ensure that the key/value pairs added
    # to the facts_map are unique
    # @param [Array] fields_to_include  An array containing the list of keys for which a
    # corresponding key/value pair from the hash_map should be added to the facts_map
    def add_flattened_hash_to_facts!(hash_map, facts_map, prefix, fields_to_include,
                                     match_style = :equals)
      if match_style.equal?(:like)
        hash_map.keys.each { |key|
          next unless fields_to_include.select { |field_key| /#{field_key}/.match(key) }
          new_key = prefix + '_' + key
          facts_map[new_key.to_sym] = hash_map[key]
        }
      elsif match_style.equal?(:equals)
        fields_to_include.each { |key|
          next unless hash_map
          if hash_map.key?(key)
            new_key = prefix + '_' + key
            facts_map[new_key.to_sym] = hash_map[key]
          end
        }
      end
    end

    # used by the add_facts_to_map! method (above) to flatten out an array of hash map
    # values (passed in as the hash_array input argument) and add a selected set of
    # key/value pairs from each of the hash map elements in the array to the facts_map
    # @param [Array] hash_array  The Array of Hash maps, each of which contains the
    # name/value pairs that should be added to the facts_map
    # @param [Hash] facts_map  The Hash map to supplement with facts from the elements
    # of the hash_array
    # @param [String] prefix  The prefix to use to ensure that the key/value pairs added
    # to the facts_map are unique
    # @param [Array] fields_to_include  An array containing the list of keys for which a
    # corresponding key/value pair from the hash_map should be added to the facts_map
    def add_flattened_array_to_facts!(hash_array, facts_map, prefix, fields_to_include)
      return unless hash_array
      count = 0
      # get the number of non-nil elements in the hash_array; will be used
      # as the count for this key (below)
      array_len_str = hash_array.select{ |item| item }.size.to_s
      count_key = prefix + "_count"
      facts_map[count_key.to_sym] = array_len_str
      hash_array.each { |element|
        next unless element
        new_prefix = prefix + count.to_s
        add_flattened_hash_to_facts!(element, facts_map, new_prefix, fields_to_include)
        count += 1
      }
    end

    # Takes the output of the lscpu command and converts it to a Hash of name/value
    # pairs (where the names are the properties, as Symbols, and the values are either Strings or arrays of
    # Strings representing the values for those properties)
    # @param command_output [String] the raw output from lscpu command
    # @param delimiter [String] the delimiter that should be used to separate the name/value pairs in the
    #     raw lscpu command output
    # @return [Hash<String, Array<String>>] a Hash map containing the names of the properties as keys and
    #     an Array of String values for that properties as the matching Hash map values.
    def lscpu_output_to_hash(command_output, delimiter)
      array = command_output.split("\n")
      split_hash = Hash.new
      delimiter = "\\#{delimiter}"
      index = 0
      array.each { |entry|
        (index += 1; next) if entry.strip.length == 0
        # first, split the entry using the delimiter, breaking the string into an array
        # of at most two strings
        split_entry = entry.split(/\s*#{delimiter}\s?/, 2)
        # then replace any characters that could be problematic in a key value with other
        # characters
        key = split_entry[0].strip.gsub(/\s+/, " ").gsub(/[\ \/\\]/, '_').gsub('.', '').gsub(/^#/, "number")
        # and, finally, determine the value that goes with the key that we just constructed
        val = ( split_entry[1] ? split_entry[1].strip : "" )
        split_hash[key] = val
      }
      split_hash
    end

    # Takes the output of the ipmitool command and converts it to a Hash of name/value
    # pairs (where the names are the properties, as Symbols, and the values are either
    # Strings or arrays of Strings representing the values for those properties).
    #
    # Note that the formats that need to be supported by this function vary widely depending
    # on the ipmitool command we are parsing output for.  As such, we will actually use a case
    # statement in this method to call the appropriate parsing function (based on the 'command'
    # value), then massage the results that are returned into a format that can be used elsewhere
    #
    # @param command_output [String] the raw output from ipmitool command
    # @param delimiter [String] the delimiter that should be used to separate the name/value pairs in the
    #     raw impitool command output
    # @return [Hash<String, Array<String>>] a Hash map containing the names of the properties as keys and
    #     an Array of String values for that properties as the matching Hash map values.
    def ipmitool_output_to_hash(command_output, delimiter, command)
      if command.equal?(:bmc_info)
        parse_bmc_info(command_output, delimiter)
      elsif command.equal?(:lan_print)
        parse_lan_print(command_output, delimiter)
      elsif command.equal?(:fru_print)
        parse_fru_print(command_output, delimiter)
      else
        lscpu_output_to_hash(command_output, delimiter).select { |k, v| !k.empty? && !v.empty?}
      end
    end

    # examples from some of the commands include the following formats:
    #
    # Device ID                 : 32
    #     ...
    # Additional Device Support :
    #    Sensor Device
    #    SDR Repository Device
    #     ...
    #
    # (Note, in this example the lines that appear underneath the 'Additional Device Support :'
    # line are all values for the 'Additional Device Support' property)
    def parse_bmc_info(command_output, delimiter)
      array = command_output.split("\n")
      split_hash = Hash.new
      delimiter = "\\#{delimiter}"
      current_key = ""
      array.each { |entry|
        next if entry.strip.length == 0
        # each entry can be either a name-value line or a name
        # line followed by a number of value lines followed by another
        # name or name-value line, so parse accordingly (collapsing the
        # value lines into an array that is referred to using the value
        # from the preceeding name line as a key)
        if !/\s*#{delimiter}\s?/.match(entry)
          # if here, we're in a 'value line', so add this to the array
          # value referenced by the current_key in the hash we're returning
          split_hash[current_key] << entry.strip
        else
          # if here, we're parsing either a 'name/value' line or a 'name' line; in either
          # case the first thing we'll do is split the entry using the delimiter, breaking
          # the string into an array of at most two strings
          split_entry = entry.split(/\s*#{delimiter}\s?/, 2)
          # then we'll replace any characters that could be problematic in a key value with
          # other characters
          key = split_entry[0].strip.gsub(/\s+/, " ").gsub(/[\ \/\\]/, '_').gsub('.', '').gsub(/^#/, "number")
          if split_entry.size == 2 && !(split_entry[1].empty?)
            # if there are two entries, then it's a name-value line, so just save the value
            # (the stripped second part of our parsed line) under (the first part) in our hash map
            split_hash[key] = split_entry[1].strip
          else
            # if there is only one entry, then this is a 'name' line; in that case, we'll save
            # this 'key' as the 'current_key' value, add an empty array to the map and continue
            # our parsing
            current_key = key
            split_hash[key] = []
          end
        end
      }
      split_hash
    end

    # a slightly more complicated is in the 'lan print' output:
    #
    # Auth Type Support       : NONE MD2 MD5 PASSWORD
    # Auth Type Enable        : Callback : MD2 MD5
    #                         : User     : MD2 MD5
    #                         : Operator : MD2 MD5
    #                             ...
    #
    # in this example, the value of the 'Auth Type Enable' field is actually a hash map, where the
    # value on this line (and the subsequent lines) should be used to construct that map.
    def parse_lan_print(command_output, delimiter)
      array = command_output.split("\n")
      split_hash = Hash.new
      delimiter = "\\#{delimiter}"
      current_key = ""
      array.each { |entry|
        next if entry.strip.length == 0
        # each entry can be either a name-value line or a number of
        # value lines that should be appended to the value added from the
        # most recent name-value line
        split_entry = entry.split(/\s*#{delimiter}\s?/, 2)
        val = split_entry[1].strip
        if !split_entry[0].empty?
          # replace any characters that could be problematic in a key value with
          # other characters
          key = split_entry[0].strip.gsub(/\s+/, " ").gsub(/[\ \/\\]/, '_').gsub('.', '').gsub(/^#/, "number")
          # it's a name-value line, so just save this key as the 'current_key' and save the value
          # (the stripped second part of our parsed line) under (the first part) in our hash map
          current_key = key
          if /\s*#{delimiter}\s?/.match(val)
            tmp_map = {}
            split_val = val.split(/\s*#{delimiter}\s?/, 2)
            tmp_map[split_val[0].strip] = split_val[1].strip
            split_hash[key] = tmp_map
          else
            split_hash[key] = val
          end
        else
          # if there is only one entry, then this is a 'value' line; in that case, we'll save
          # this 'value' under the 'current_key' value (appending it to the value that might
          # be there)
          if split_hash[current_key].is_a?(Array)
            split_hash[current_key] << val
          elsif split_hash[current_key].is_a?(Hash)
            if /\s*#{delimiter}\s?/.match(val)
              tmp_map = split_hash[current_key]
              split_val = val.split(/\s*#{delimiter}\s?/, 2)
              tmp_map[split_val[0].strip] = split_val[1].strip
              split_hash[current_key] = tmp_map
            end
          else
            split_hash[current_key] = [split_hash[current_key], val]
          end
        end
      }
      split_hash
    end

    # Finally, things get extremely complicated when we look at the output of the 'fru print'
    # command:
    #
    # FRU Device Description : Builtin FRU Device (ID 0)
    #  Board Mfg Date        : Fri Jun 20 07:10:00 2014
    #  Board Mfg             : DELL
    #  Board Product         : PowerEdge R720
    #  Board Serial          : CN7016346J01AM
    #  Board Part Number     : 0X3D66A07
    #  Product Manufacturer  : DELL
    #  Product Name          : WIN-QB9K8RM13CA
    #  Product Version       : 01
    #  Product Serial        : CRCGY12
    #  Product Asset Tag     : AH847011
    #
    # FRU Device Description : iDRAC7
    #  Board Mfg Date        : Fri Jun 20 07:10:00 2014
    #  Board Mfg             : DELL
    #  Board Product         : PowerEdge R720
    #     ...
    #
    # Note that in the output of this command the output is actually an array of hash maps, where
    # each block represents one FRU entry.
    def parse_fru_print(command_output, delimiter)
      array = command_output.split("\n")
      split_hash = Hash.new
      delimiter = "\\#{delimiter}"
      index = 0
      array.each { |entry|
        (index += 1; next) if entry.strip.length == 0
        # first, split the entry using the delimiter, breaking the string into an array
        # of at most two strings
        split_entry = entry.split(/\s*#{delimiter}\s?/, 2)
        # then replace any characters that could be problematic in a key value with other
        # characters
        key = split_entry[0].strip.gsub(/\s+/, " ").gsub(/[\ \/\\]/, '_').gsub('.', '').gsub(/^#/, "number")
        # and, finally, determine the value that goes with the key that we just constructed
        val = ( split_entry[1] ? split_entry[1].strip : "" )
        split_hash["fru_#{index}_" + key] = val
      }
      split_hash
    end

    # Takes the output of a lshw command and converts it to a Hash of name/value
    # pairs (where the names are the properties, as Symbols, and the values are Hash maps containing
    # the values for those properties).  Note:  the values themselves may map via their key values
    # to a deeper Array/Hash map; containment is implied by the level of indentation of the lines
    # that start with an asterisk (once any leading spaces are stripped off) and the type of value
    # (either an Array of maps or a Hash map) is implied by the structure of that line (lines that
    # look like "*-key:N", where N is an integer imply an Array of Hash maps should be constructed
    # under a key derived from key name, while those without the integer value imply a single Hash
    # map is contained under that key)
    # @param command_output [String] the raw output from lshw command
    # @param delimiter [String] the delimiter that should be used to separate the name/value pairs in the
    #     raw lshw command output
    # @return [Hash<String, Array<String>>] a Hash map containing the names of the properties as keys and
    #     a Hash map containing the values for those properties.
    def lshw_output_to_hash(command_output, delimiter)
      array = command_output.split("\n")
      # first, iterate through the output and determine the containment implied by the indentation
      # of each of the sections in the output.  As an example, the output of the "lshw -c memory"
      # command looks like the following:
      #
      #  *-firmware
      #       description: BIOS
      #          ...
      #  *-memory
      #       description: System Memory
      #          ...
      #       size: 36GiB
      #     *-bank:0
      #          description: DIMM Synchronous 1333 MHz (0.8 ns)
      #             ...
      #     *-bank:N
      #  *-cache:0
      #     ...
      # which implies a structure like the following
      # { "firmware" => { "description" => "BIOS" ... }
      #   "memory" => { "description" => "System Memory" ... bank_array => [ { "description" => "DIMM..." }
      #                                                                             ...
      #                                                                      { "description" => "DIMM..." } ] }
      #   "cache_array" => [ { "description" => "L1 cache" ... }
      #                             ...
      #                      { "description" => "L3 cache" ... }
      #                  ]
      # }
      parse_array = []
      prev_indent = 0
      prev_array_fieldname = ""
      indent_level = -1
      array.each { |line|
        name_line = /^(\s*)\*\-([A-Za-z]+)(\:?[0-9]*)?$/.match(line) ||
            /^(\s+)\*\-([A-Za-z]+)\:?([0-9]*)\s+(DISABLED)$/.match(line) ||
            /^(\s+)\*\-([A-Za-z]+)\:?([0-9]*)\s+(UNCLAIMED)$/.match(line)
        if name_line && name_line[1].length > prev_indent && name_line[2] != prev_array_fieldname
          indent_level += 1
          prev_indent = name_line[1].length
        elsif name_line && name_line[1].length < prev_indent && name_line[2] != prev_array_fieldname
          indent_level -= 1
          prev_indent = name_line[1].length
        end
        # if name_line is non-nil, then name_line[2] is the name value for the underlying
        # Hash map or Array, otherwise this line is a value for the previously named element
        # of the containing Hash map
        if name_line
          key_name = name_line[2]
          key_name = key_name[1..-1] if key_name.start_with?(':')
          # if the third element is non-nil, then this represents one element of an array of
          # maps that should be used for this property; else we're just looking at the name
          # of a map of name/value pairs for this property (the exception to this is the
          # "network" output, which is always an array but never includes numbers, so we'll
          # just force it to be an array)
          if name_line[3].length > 0 || key_name == "network" || key_name == "disk"
            key = key_name + "_array"
            parse_array << { :indent_level => indent_level, :type => "map_array",
                             :name => key, :is_enabled => (name_line[4] != "DISABLED"),
                             :unclaimed => (name_line[4] != "UNCLAIMED") }
          else
            key = key_name
            parse_array << { :indent_level => indent_level, :type => "map", :name => key }
          end
          prev_array_fieldname = key_name
        else
          # it's a value, so parse it using the delimiter that was passed in as an argument
          # to the function (above) and save the result in the parse_array...first, parse the
          # line to obtain the key by splitting on the delimiter, and replacing characters
          # that could be problematic in a key value with other characters
          key = line.split(/\s*#{delimiter}\s?/)[0].strip.gsub(/\s+/," ").gsub(' ','_').gsub('.','').gsub(/^#/,"number")
          # then, split the line on the delimiter again, this time to determine the value that goes
          # with the key that we just constructed
          val = line.split(/\s*#{delimiter}\s?/,2)[1].strip
          parse_array << { :indent_level => indent_level, :type => "name_value",
                           :name => key, :value => val }
        end
      }
      # now, use the structure that we determined in the first iteration through the array to
      # construct the Hash that we're going to return to the caller
      array_to_hash(parse_array)
    end

    # Used to convert the parse array constructed, above, to a Hash map containing the meta-data
    # from running a "lshw" command
    def array_to_hash(parse_array, start_idx = 0)
      current_idx = start_idx
      current_map = {}
      top_level_map = current_map
      current_map_name = nil
      prev_indent = parse_array[current_idx][:indent_level] if current_idx < parse_array.length
      map_stack = []
      map_name_stack = []
      while current_idx < parse_array.length
        type = parse_array[current_idx][:type]
        current_indent = parse_array[current_idx][:indent_level]
        if /^.*_array$/.match(type)
          # if we're not starting with an array, and if we're shifting to a "contained" array,
          # then save the current map name for later
          map_name_stack.push(current_map_name) if current_indent > prev_indent
          current_map_name = parse_array[current_idx][:name]
          # this is the header for a map that should be added as part of an array of entries of
          # a similar type
          if current_indent > prev_indent
            # shifting to a higher indentation level, so push the current map into the stack
            map_stack.push(current_map)
            # and get a reference to the "containing" map to use for adding material to
            current_map = map_stack.last[map_name_stack.last]
            current_idx, array_vals = parse_array_value_set(parse_array, current_idx)
            if current_map.is_a?(Array)
              current_map[current_map.length-1][current_map_name] = array_vals
            else
              current_map[current_map_name] = array_vals
            end
            prev_indent = current_indent
          else
            if current_indent < prev_indent
              current_map = map_stack.pop
              prev_indent = current_indent
            end
            current_idx, array_vals = parse_array_value_set(parse_array, current_idx)
            if current_map.key?(current_map_name)
              current_map[current_map_name] << array_vals[0]
            else
              current_map[current_map_name] = array_vals
            end
          end
        elsif type == "name_value"
          # this line is the start of a name-value pair section of the lshw output and should be added
          # as a map of properties under the current key value
          current_idx, current_map[current_map_name] = parse_name_value_set(parse_array, current_idx)
        elsif type == "map"
          # this line represents the name of an entry that will point to a Hash map of properties
          # (and those properties may be simple strings or an Array map may also contain)
          current_map_name = parse_array[current_idx][:name]
          current_idx += 1
        end
      end
      top_level_map
    end

    # Used obtain a Hash map of the name/value pairs that appear under a common
    # top-level key. Examples of this sort of data include the meta-data associated
    # with the "firmware" key in the output of the "lshw -c memory" command (and much
    # of the meta-data gathered for any of the other data types, including the data
    # contained within most of the "array values" parsed in the parse_array_value_set
    # method, below)
    def parse_name_value_set(parse_array, start_idx, is_enabled = true, unclaimed = true)
      output_hash = {}
      output_hash["DISABLED"] = true unless is_enabled
      output_hash["UNCLAIMED"] = true unless unclaimed
      current_idx = start_idx
      type = parse_array[current_idx][:type]
      # as long as we continue to see name-value pairs and don't reach the end of the
      # parse_array, continue appending name/value pairs to the output hash-map
      while type == "name_value" && current_idx < parse_array.length
        output_hash[parse_array[current_idx][:name]] = parse_array[current_idx][:value]
        current_idx += 1
        type = parse_array[current_idx][:type] if current_idx < parse_array.length
      end
      # and return the output hash-map to the caller
      # p "at #{current_idx}: #{output_hash}"
      [current_idx, output_hash]
    end

    # Used to parse "array values" (i.e. values that contain an array of similar types of things),
    # converting them to an array of Hash maps.
    #
    # Examples of this type of data include the CPU and Logical CPU array values in output of
    # the "lshw -c processor" command, the memory bank and cache arrays in the output of the
    # "lshw -c memory" command, and the disk array in the output of the "lshw -c disk" command
    def parse_array_value_set(parse_array, start_idx)
      output_array = []
      current_idx = start_idx
      type = parse_array[current_idx][:type]
      curr_name = parse_array[current_idx][:name]
      is_enabled = parse_array[current_idx][:is_enabled]
      unclaimed = parse_array[current_idx][:unclaimed]

      prev_name = curr_name
      # as long as we continue to see name-value pairs and don't reach the end of the
      # parse_array, continue appending name/value pairs to the output hash-map
      while type == "map_array" && curr_name == prev_name && current_idx < parse_array.length
        current_idx += 1
        current_idx, output_hash = parse_name_value_set(parse_array, current_idx, is_enabled, unclaimed)
        output_array << output_hash unless output_hash["DISABLED"]
        if current_idx < parse_array.length
          type = parse_array[current_idx][:type]
          curr_name = parse_array[current_idx][:name]
          is_enabled = parse_array[current_idx][:is_enabled]
          unclaimed = parse_array[current_idx][:unclaimed]
        end
      end
      # and return the output hash-map to the caller
      [current_idx, output_array]
    end

    # this method cleans up the keys in the input fact_map so that they don't include
    # any characters that could cause problems later on...i.e. any characters from following
    # string: "!@#\$%\^&*()=+\[\]\{\}"
    def clean_fact_map_keys!(facts_map)
      facts_map.keys.each { |key|
        # search each key to see if there any offending characters
        # (if so, we'll refer to the key as an "offending key", below)
        key_str = key.to_s
        if /[!@#\$%\^&*()=+\[\]\{\}]/ =~ key_str
          # if there is a match, then we'll create a new entry in the map using a
          # "cleansed" key (i.e. a key with all of the offending characters removed),
          # store the old value under the new key, and and remove the old key-value pair
          # that stored the same data under the offending key
          new_key = key_str.gsub(/[!@#\$%\^&*()=+\[\]\{\}]/,"")
          facts_map[new_key.to_sym] = facts_map[key]
          facts_map.delete(key)
          logger.debug("offending key '#{key_str}' changed to #{new_key}")
        end
      }
    end

  end
end
