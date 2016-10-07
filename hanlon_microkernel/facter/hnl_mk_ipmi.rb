# Gathers hardware-related facts from the underlying system pertaining
# to IPMI / BMC. Information gathered here is exposed directly as 
# Facter facts for the purpose of node registration. 
#

require 'facter'

attributes = {}
if Facter.value('virtual') == 'physical'
  # add the facts that result from running the "ipmitool mc info" command
  last_keyname = ''
  %x[sudo ipmitool bmc info 2> /dev/null].split(/\n/).each do |line|
    if line.include? ':'
      # normal key/value entries
      key,val = line.split(/:/)
      keyname = key.strip.downcase.tr(' ', '_')
      val.strip! unless val.nil?
      
      case keyname
      when 'additional_device_support'
        last_keyname = 'mk_ipmi_' + keyname
      when 'aux_firmware_rev_info'
        last_keyname = 'mk_ipmi_' + keyname
      else
        attributes['mk_ipmi_' + keyname] = val
      end
    else
      # multi value entries for last_keyname
      attributes[last_keyname] ||= []
      attributes[last_keyname] << line.strip
    end
  end
      
  # add the facts that result from running the "ipmitool lan print" command
  %x[sudo ipmitool lan print 2> /dev/null].split(/\n/).each do |line|
    key,val = line.split(/:/)
    keyname = key.strip.downcase.tr(' ', '_')
    val.strip! unless val.nil?
      
    case keyname
    when /set_in_progress|auth_type_enable/
      # ignore
    when /^$/
      # ignore
    else
      attributes['mk_ipmi_' + keyname] = val
    end
  end
  
  # add the facts that result from running the "ipmitool fru print" command
  fru_id = '0'
  %x[sudo ipmitool fru print 2> /dev/null].split(/\n/).each do |line|
    if line.include? ':'
      key,val = line.split(/:/)
      keyname = key.strip.downcase.tr(' ', '_')
      val.strip! unless val.nil?
      
      case keyname
      when 'fru_device_description'
        # value has the device id in it
        fru_id = val.gsub(/^.*ID\s+(\d+).*$/, '\1')
      else
        attributes['mk_ipmi_fru_' + fru_id + '_' + keyname] = val
      end
    end
  end
end

attributes.each_pair do |fact,value|
  # facts are not allowed to have periods in them
  Facter.add(fact.tr('.', '_') ) do
    setcode { value }
  end
end

