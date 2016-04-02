# Gathers hardware-related facts from the underlying system pertaining
# to the system memory. Information gathered here is exposed directly as 
# Facter facts for the purpose of node registration. 
#
#

# add the '/usr/local/lib/ruby' directory to the LOAD_PATH
# (this is where the hanlon_microkernel module files are placed by
# our Dockerfile)
$LOAD_PATH.unshift('/usr/local/lib/ruby')

require 'facter'


# Takes the output of a lshw command and converts it to a Hash of name/value
# pairs (where the names are the properties, as Symbols, and the values are
# Hash maps containing the values for those properties).  Note:  the values
# themselves may map via their key values to a deeper Array/Hash map;
# containment is implied by the level of indentation of the lines that start
# with an asterisk (once any leading spaces are stripped off) and the type of
# value (either an Array of maps or a Hash map) is implied by the structure of
# that line (lines that3 look like "*-key:N", where N is an integer imply Array
# of Hash maps should be constructed under a key derived from key name, while
# those without the integer value imply a single Hash map is contained under
# that key)
#
# @param command_output [String] the raw output from lshw command
# @param delimiter [String] the delimiter that should be used to separate the
#     name/value pairs in the raw lshw command output
# @return [Hash<String, Array<String>>] a Hash map containing the names of the
#     properties as keys and a Hash map containing the values for those
#     properties.
def def_to_hash(definition, delimiter=':')
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
  result = {}
  
  unless definition.empty?
    if definition =~ /\s\*-\w+/
      # definition has sub-definitions in it
      definition =~ /^(\s+)\*-\w/
      indent = $1
      
      # break into sub-definitions. first one may be only values
      parts = definition.split(/^\s{#{indent.length}}\*-/)
      
      # process the first part. returns hash or nothing
      result.merge!(def_to_hash(parts.shift))
       
      parts.each do |subdef|
        lines = subdef.split(/\n/)
        unless lines.empty?  
          # first line is the title with optional instance
          title, instance = lines.shift.split(':')
          
          # check for array of titles or start an array of titles
          if result.has_key? "#{title}_array"
            result["#{title}_array"] << def_to_hash(lines.join("\n"))
          elsif result.has_key? title
            result["#{title}_array"] = [ result[title] ]
            result.delete title
            result["#{title}_array"] << def_to_hash(lines.join("\n"))
          else
            result[title] = def_to_hash(lines.join("\n"))
          end
        end
      end
    else
      # no sub-definitions, just process the attributes
      result.merge! Hash[ 
          definition.split(/\n/).collect do |l| 
            l =~ /^\s*([^#{delimiter}]+)#{delimiter}\s+(.*)\s*$/; v=$2; [$1.gsub(/\s/, '_'), v] 
          end 
      ]
    end
  end
  
  result
end


def calculate_bytes(label)
  label =~ /^(\d+)([a-zA-Z])/
  size = $1.to_i
  unit = $2.upcase
  case unit
  when 'T'
    size * (1024 ** 4)
  when 'G'
    size * 1073741824
  when 'M'
    size * 1048576
  when 'K'
    size * 1024
  end
end


# now "right size" the memory -- starting at MB
def pretty_memory_size(bytes)
  case bytes
  when 0..1052266988     # 0 - a bit over 980MB
    size = bytes / 1048576
    if size < 1
      "#{size.round(2)}MB"
    else
      "#{size.round}MB"
    end
  when 1052266988..(1024 ** 4 - 5368709120)   # 980MB - (1TB - 5GB)
    size = bytes / 1073741824
    if size < 1
      "#{size.round(2)}GB"
    else
      "#{size.round}GB"
    end
  else
    size = bytes / (1024 ** 4)
    if size < 1
      "1TB"
    else
      "#{size.round}TB"
    end
  end
end



virtual_type = Facter.value('virtual')
lshw_cmd =  (virtual_type && virtual_type == 'kvm') ? 'lshw -disable dmi' : 'lshw'
lshw_c_memory_str = %x[sudo #{lshw_cmd} -c memory 2> /dev/null]

# process the results from lshw -c memory
memory = def_to_hash(lshw_c_memory_str)

# Create the facts for the firmware info
%w{description vendor physical_id version date size capabilities capacity}.each do |fact|
  if memory['firmware'].has_key? fact
    val = memory['firmware'][fact]
    Facter.add("mk_hw_fw_#{fact}") do
      setcode { val }
    end
  end
end

# Create the facts for the memory info
if memory.has_key? 'memory'
  # not all systems define top level memory summary
  %w{description physical_id slot}.each do |fact|
    if memory['memory'].has_key? fact
      val = memory['memory'][fact]
      Facter.add("mk_hw_mem_#{fact}") do
        setcode { val }
      end
    end
  end
end

# Create a special fact for memory size
if memory.has_key? 'memory' and memory['memory'].has_key? 'size'
  val = memory['memory']['size']
else
  # without size specified, we need to add all the banks together
  bytes = 0
  memory['memory_array'].each do |procmem|
    procmem.has_key? 'bank_array' and procmem['bank_array'].each do |bank|
      if bank.has_key? 'size'
        bytes += calculate_bytes(bank['size'])
      end
    end
  end
      
  # finally... create the fact
  Facter.add("mk_hw_mem_size") do
    setcode { pretty_memory_size(bytes) }
  end
end

# slot info is going to need a bunch of work
#slot_info = memory['memory']['bank_array'].select {|entry| entry['size']}
#Facter.add("mk_hw_mem_slot_info") do
#  setcode { slot_info }
#end
