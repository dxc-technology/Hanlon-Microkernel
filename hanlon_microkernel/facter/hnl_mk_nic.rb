# Gathers hardware-related facts from the underlying system pertaining
# to the network interfaces. Information gathered here is exposed directly as 
# Facter facts for the purpose of node registration. 
#

require 'facter'


virtual_type = Facter.value('virtual')
lshw_cmd =  (virtual_type && virtual_type == 'kvm') ? 'lshw -disable dmi' : 'lshw'
lshw_c_network_str = %x[sudo #{lshw_cmd} -c network 2> /dev/null]

# process the results from lshw -c network
nics = 0
lshw_c_network_str.split(/\s\s\*-/).each do |definition|
  unless definition.empty?
    lines = definition.split(/\n/)
    # section title is on the first line
    network = lines.shift.tr(':', '')
    nics += 1
    # Create a hash of attributes for each section (i.e. cpu)
    attribs = Hash[ lines.collect do |l| 
      begin
        l =~ /^\s*([^:]+):\s+(.*)\s*$/; v=$2; [$1.gsub(/\s/, '_'), v]
      rescue NoMethodError
        if Facter.debugging?
          puts "Error: (network class) unable to parse #{l}"
        end
      end
    end ]
    attribs.each_pair do |attrib, val|
      Facter.add("mk_hw_#{network}_#{attrib}") do
        setcode { val }
      end
    end
  end
end

# report on the number NICs found
Facter.add("mk_hw_nic_count") do
  setcode { nics }
end
