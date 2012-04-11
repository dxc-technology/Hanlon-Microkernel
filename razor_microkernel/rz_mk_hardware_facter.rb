# Gathers hardware-related facts from the underlying system (used by the
# rz_mk_registration_manager to gather these sorts of facts in order to
# supplement the facts gathered using Facter during the node registration
# process)
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

require 'singleton'
require 'razor_microkernel/logging'

# set up a global variable that will be used in the RazorMicrokernel::Logging mixin
# to determine where to place the log messages from this script (will be combined
# with the other log messages for the Razor Microkernel Controller)
RZ_MK_LOG_PATH = "/var/log/rz_mk_controller.log"

module RazorMicrokernel
  class RzMkHardwareFacter

    include Singleton

    # include the RazorMicrokernel::Logging mixin (which enables logging)
    include RazorMicrokernel::Logging

    def add_facts_to_map!(facts_map)
      # add the facts that result from running the "lscpu" command
      lscpu_facts_str = %x[lscpu]
      lscpu_hash = lscpu_output_to_hash(lscpu_facts_str, ":")
      lscpu_hash.each { |key, value|
        new_key = "mk_hw_cpu" + key
        facts_map[new_key] = value
      }
      # and add the facts that result from running a few "lshw" commands
      lshw_c_memory_str = %x[sudo lshw -c memory]
      lshw_c_memory_str.each { |key, value|
        new_key = "mk_hw_mem" + key
        facts_map[new_key] = value
      }
      lshw_c_disk_str = %x[sudo lshw -c disk]
      lshw_c_disk_str.each { |key, value|
        new_key = "mk_hw_disk" + key
        facts_map[new_key] = value
      }
      lshw_c_processor_str = %x[sudo lshw -c processor]
      lshw_c_processor_str.each { |key, value|
        new_key = "mk_hw_proc" + key
        facts_map[new_key] = value
      }
    end

    private

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
        # parse that entry to obtain the key, first by splitting on the delimiter, then
        # by replacing characters that could be problematic in a key value with other
        # characters
        key = entry.split(/\s*#{delimiter}\s?/)[0].strip.gsub(/\s+/," ").gsub(' ','_').gsub('.','').gsub(/^#/,"number")
        # next, split the entry on the delimiter again, this time to determine the value that goes
        # with the key that we just constructed
        val = entry.split(/\s*#{delimiter}\s?/,2)[1].strip
        split_hash[key] = val
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
      indent_level = -1
      array.each { |line|
        name_line = /^(\s+)\*\-([A-Za-z]+)\:?([0-9]*)$/.match(line) ||
            /^(\s+)\*\-([A-Za-z]+)\s+(DISABLED)$/.match(line)
        if name_line && name_line[1].length > prev_indent
          indent_level += 1
          prev_indent = name_line[1].length
        elsif name_line && name_line[1].length < prev_indent
          indent_level -= 1
          prev_indent = name_line[1].length
        end
        # if name_line is non-nil, then name_line[2] is the name value for the underlying
        # Hash map or Array, otherwise this line is a value for the previously named element
        # of the containing Hash map
        if name_line
          # if the third element is non-nil, then this represents one element of an array of
          # maps that should be used for this property; else we're just looking at the name
          # of a map of name/value pairs for this property
          if name_line[3].length > 0
            key = name_line[2] + "_array"
            parse_array << { :indent_level => indent_level, :type => "map_array",
                             :name => key, :is_enabled => (name_line[3] != "DISABLED") }
          else
            key = name_line[2]
            parse_array << { :indent_level => indent_level, :type => "map", :name => key }
          end
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
    def parse_name_value_set(parse_array, start_idx, is_enabled = true)
      output_hash = {}
      output_hash["DISABLED"] = true unless is_enabled
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
      prev_name = curr_name
      # as long as we continue to see name-value pairs and don't reach the end of the
      # parse_array, continue appending name/value pairs to the output hash-map
      while type == "map_array" && curr_name == prev_name && current_idx < parse_array.length
        current_idx += 1
        current_idx, output_hash = parse_name_value_set(parse_array, current_idx, is_enabled)
        output_array << output_hash
        if current_idx < parse_array.length
          type = parse_array[current_idx][:type]
          curr_name = parse_array[current_idx][:name]
          is_enabled = parse_array[current_idx][:is_enabled]
        end
      end
      # and return the output hash-map to the caller
      [current_idx, output_array]
    end

  end
end
