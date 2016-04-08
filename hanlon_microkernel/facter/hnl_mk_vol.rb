# Gathers hardware-related facts from the underlying system pertaining
# to the disk volumes. Information gathered here is exposed directly as 
# Facter facts for the purpose of node registration. 
#

require 'facter'


virtual_type = Facter.value('virtual')
lshw_cmd =  (virtual_type && virtual_type == 'kvm') ? 'lshw -disable dmi' : 'lshw'
lshw_c_volume_str = %x[sudo #{lshw_cmd} -c volume 2> /dev/null]

# process the results from lshw -c volume
vols = 0
lshw_c_volume_str.split(/\s\s\*-/).each do |definition|
  unless definition.empty?
    lines = definition.split(/\n/)
    # section title is on the first line
    volume = lines.shift.tr(':', '') and vols += 1

    # Create a hash of attributes for each section (i.e. cpu)
    attribs = Hash[ lines.collect { |l| l =~ /^\s*([^:]+):\s+(.*)\s*$/; v=$2; [$1.gsub(/\s/, '_'), v] } ]
    attribs.each_pair do |attrib, val|
      Facter.add("mk_hw_#{volume}_#{attrib}") do
        setcode { val }
      end
    end
  end
end

# Report on the number volumes found
Facter.add("mk_hw_volume_count") do
  setcode { vols }
end
