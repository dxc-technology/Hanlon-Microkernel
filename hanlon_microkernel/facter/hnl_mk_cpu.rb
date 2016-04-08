# Gathers hardware-related facts from the underlying system pertaining
# to the processors. Information gathered here is exposed directly as 
# Facter facts for the purpose of node registration. 
#

require 'facter'


virtual_type = Facter.value('virtual')
lshw_cmd =  (virtual_type && virtual_type == 'kvm') ? 'lshw -disable dmi' : 'lshw'
lshw_c_cpu_str = %x[sudo #{lshw_cmd} -c cpu 2> /dev/null]

# process the results from lshw -c cpu
cpus = 0
lshw_c_cpu_str.split(/\s\s\*-/).each do |definition|
  unless definition.empty?
    lines = definition.split(/\n/)
    # section title is on the first line
    cpu = lines.shift.tr(':', '')
    unless cpu =~ /disabled/i
      cpus += 1
      # Create a hash of attributes for each section (i.e. cpu)
      attribs = Hash[ lines.collect { |l| l =~ /^\s*([^:]+):\s+(.*)\s*$/; v=$2; [$1.gsub(/\s/, '_'), v] } ]
      attribs.each_pair do |attrib, val|
        Facter.add("mk_hw_#{cpu}_#{attrib}") do
          setcode { val }
        end
      end
    end
  end
end

# report on the number of CPUs
Facter.add("mk_hw_cpu_count") do
  setcode { cpus }
end

# process the results from lscpu
facts_to_report = %w{Architecture BogoMIPS Byte_Order CPU_MHz CPU_family CPU_op-modes 
                     L1d_cache L1i_cache L2_cache L3_cache Model Stepping Vendor_ID 
                     Virtualization Virtualization_type Hypervisor_vendor
                     Threads_per_core Cores_per_socket Sockets
                     NUMA_nodes}
%x[lscpu].split(/\n/).each do |line|
  line =~ /^([^:]+):\s*(.*)\s*$/
  if $1
    # map out chars that should not be part of the key
    key = $1.tr(' ', '_').tr('()', '')
    val = $2
    if facts_to_report.include? key
      Facter.add("mk_hw_lscpu_#{key}") do
        setcode { val }
      end
    end
  end
end

# report on the number of cores available
Facter.add("mk_hw_core_count") do
  setcode { Facter.value('mk_hw_lscpu_cores_per_socket').to_i * 
            Facter.value('mk_hw_lscpu_sockets').to_i }
end
