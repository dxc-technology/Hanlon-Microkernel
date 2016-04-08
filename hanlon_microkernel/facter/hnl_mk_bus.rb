# Gathers hardware-related facts from the underlying system pertaining
# to the system buses. Information gathered here is exposed directly as 
# Facter facts for the purpose of node registration. 
#

require 'facter'



virtual_type = Facter.value('virtual')
lshw_cmd =  (virtual_type && virtual_type == 'kvm') ? 'lshw -disable dmi' : 'lshw'
lshw_c_bus_str = %x[sudo #{lshw_cmd} -c bus 2> /dev/null]

# build the results into a Hash
results = {}
lshw_c_bus_str.split(/\s\s\*-/).each do |definition|
  unless definition.empty?
    lines = definition.split(/\n/)
    item = lines.shift.tr(':', '')
    attribs = Hash[ lines.collect { |l| l =~ /^\s*([^:]+):\s+(.*)\s*$/; v=$2; [$1.gsub(/\s/, '_'), v] } ]
    results[item] = attribs
  end
end


# report out the core values
%w{description product vendor version serial physical_id}.each do |fact|
  if results['core'].has_key? fact
    val = results['core'][fact]
    Facter.add("mk_hw_bus_#{fact}") do
      setcode { val }
    end
  end
end

# now report the rest of the bus information
results.delete('core')
results.keys.each do |bus|
  results[bus].each do |attrib, val|
    Facter.add("mk_hw_bus_#{bus}_#{attrib}") do
      setcode { val }
    end
  end
end
