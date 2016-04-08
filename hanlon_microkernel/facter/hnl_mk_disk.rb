# Gathers hardware-related facts from the underlying system pertaining
# to the physical disks. Information gathered here is exposed directly as 
# Facter facts for the purpose of node registration. 
#

require 'facter'


virtual_type = Facter.value('virtual')
lshw_cmd =  (virtual_type && virtual_type == 'kvm') ? 'lshw -disable dmi' : 'lshw'
lshw_c_disk_str = %x[sudo #{lshw_cmd} -c disk 2> /dev/null]

# process the results from lshw -c disk
disks = 0
lshw_c_disk_str.split(/\s\s\*-/).each do |definition|
  unless definition.empty?
    lines = definition.split(/\n/)
    # section title is on the first line
    disk = lines.shift.tr(':', '')
    disks += 1
    # Create a hash of attributes for each section (i.e. cpu)
    attribs = Hash[ lines.collect { |l| l =~ /^\s*([^:]+):\s+(.*)\s*$/; v=$2; [$1.gsub(/\s/, '_'), v] } ]
    attribs.each_pair do |attrib, val|
      Facter.add("mk_hw_#{disk}_#{attrib}") do
        setcode { val }
      end
    end
  end
end

Facter.add("mk_hw_disk_count") do
  setcode { disks }
end
