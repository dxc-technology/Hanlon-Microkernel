# Gathers hardware-related facts from the underlying system pertaining
# to the system. Information gathered here is exposed directly as 
# Facter facts for the purpose of node registration. 
#

require 'facter'


virtual_type = Facter.value('virtual')
lshw_cmd =  (virtual_type && virtual_type == 'kvm') ? 'lshw -disable dmi' : 'lshw'
lshw_c_system_str = %x[sudo #{lshw_cmd} -c system 2> /dev/null]

# process the results from lshw -c disk
disks = 0
lshw_c_system_str.split(/\s\s\*-/).each do |definition|
  unless definition.empty?
    lines = definition.split(/\n/)
    
    # Create a hash of attributes for each section (i.e. cpu)
    attribs = Hash[ lines.collect do |l| 
      begin
        l =~ /^\s*([^:]+):\s+(.*)\s*$/; v=$2; [$1.gsub(/\s/, '_'), v] 
      rescue NoMethodError
        if Facter.debugging?
          puts "Error: (system class) unable to parse #{l}"
        end
      end
    end ]
    attribs.each_pair do |attrib, val|
      Facter.add("mk_hw_sys_#{attrib}") do
        setcode { val }
      end
    end
  end
end

