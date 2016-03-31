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

require 'facter'



virtual_type = Facter.value('virtual')
lshw_cmd =  (virtual_type && virtual_type == 'kvm') ? 'lshw -disable dmi' : 'lshw'
lshw_c_cpu_str = %x[sudo #{lshw_cmd} -c cpu 2> /dev/null]

# build the results into a Hash
results = {}
lshw_c_cpu_str.split(/\s\s\*-/).each do |definition|
  unless definition.empty?
    lines = definition.split(/\n/)
    item = lines.shift.tr(':', '')
    attribs = Hash[ lines.collect { |l| l =~ /^\s*([^:]+):\s+(.*)\s*$/; v=$2; [$1.gsub(/\s/, '_'), v] } ]
    results[item] = attribs
  end
end



results.keys.each do |cpu|
  results[cpu].each_pair do |k, v|
    Facter.add("mk_hw_#{cpu}_#{k}") do
      setcode { v }
    end
  end
end


# process the results from lscpu
facts_to_report = %w{Architecture BogoMIPS Byte_Order CPU_MHz CPU_family CPU_op-modes 
                     L1d_cache L1i_cache L2_cache L3_cache Model Stepping Vendor_ID 
                     Virtualization}
%x[lscpu].split(/\n/).each do |line|
  line =~ /^([^:]+):\s*(.*)\s*$/
  if $1
    key = $1
    val = $2
    key.tr!(' ', '_')
    key.tr!('()', '')
    if facts_to_report.include? key
      Facter.add("mk_hw_lscpu_#{key}") do
        setcode { val }
      end
    end
  end
end

