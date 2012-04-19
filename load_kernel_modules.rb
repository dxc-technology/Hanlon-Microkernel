#!/usr/bin/env ruby

# this is the load_kernel_modules.rb script
#
# it manages the process of loading the appropriate kernel modules when the
# Microkernel boots.  It uses the facts gathered by Facter to determine what sort
# of environment the Microkernel has been loaded into (virtual or not? if virtual,
# what sort of virtual environment is it?) to determine what, if any, additional
# kernel modules should be loaded when the system boots and loads those kernel
# modules.  This script will be placed in the '/usr/local/bin' directory within
# the Microkernel and invoked from the '/opt/bootlocal.sh' script when the system
# boots
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

require 'rubygems'
require 'facter'

kernel_module_root = "/lib/modules/#{%x[uname -r].strip}/kernel/"
vm_kernel_modules = %W[fs/vmblock/vmblock.ko drivers/misc/vmsync.ko
        drivers/misc/vmci.ko drivers/net/vmxnet.ko fs/vmhgfs/vmhgfs.ko]

# if it's a VMware-based environment, then load the kernel modules
# provided by the (pre-installed) open-vm-tools package
if Facter.is_virtual && Facter.virtual == 'vmware'
   modules_changed = false
   changed_modules = []
   lsmod_output = %x[sudo lsmod]
   vm_kernel_modules.each { |module_subpath|
     module_name = module_subpath.split("/")[-1].split('.')[0]
     name_plus_path = kernel_module_root + module_subpath
     module_regexp = Regexp.new(module_name)
     module_loaded = module_regexp.match(lsmod_output)
     unless module_loaded
       %x[sudo insmod #{name_plus_path}]
       changed_modules << module_name
       modules_changed = true unless modules_changed
     end
   }
  %x[sudo depmod -a] if modules_changed
  puts "Modules installed: #{changed_modules.join(", ")}" if modules_changed
else
  modules_changed = false
  changed_modules = []
  vm_kernel_modules.each { |module_subpath|
    module_name = module_subpath.split("/")[-1].split('.')[0]
    name_plus_path = kernel_module_root + module_subpath
    module_regexp = Regexp.new(module_name)
    module_loaded = module_regexp.match(lsmod_output)
    if module_loaded
      %x[sudo rmmod #{name_plus_path}] unless !mod_info || mod_info.length == 0
      changed_modules << module_name
      modules_changed = true unless modules_changed
    end
  }
  %x[sudo depmod -a] if modules_changed
  puts "Modules removed: #{changed_modules.join(", ")}" if modules_changed
end
