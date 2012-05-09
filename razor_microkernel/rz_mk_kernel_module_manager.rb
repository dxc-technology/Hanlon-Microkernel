# this is the RzMkKernelModuleManager class
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
require 'json'
require 'open-uri'
require 'singleton'
require 'razor_microkernel/logging'
require 'razor_microkernel/rz_mk_configuration_manager'

# set up a global variable that will be used in the RazorMicrokernel::Logging mixin
# to determine where to place the log messages from this script (will be combined
# with the other log messages for the Razor Microkernel Controller)
RZ_MK_LOG_PATH = "/var/log/rz_mk_controller.log"

module RazorMicrokernel
  class RzMkKernelModuleManager
    include Singleton
    # include the RazorMicrokernel::Logging mixin (which enables logging)
    include RazorMicrokernel::Logging

    def initialize
      @vmware_open_vm_tools_mods = %W[vmblock vmsync vmci vmxnet vmhgfs]
    end

    def load_kernel_modules
      # get a reference to the Configuration Manager instance (a singleton)
      config_manager = (RazorMicrokernel::RzMkConfigurationManager).instance

      # if the config file exists and if the kmod_install_list_uri property exists in the configuration,
      # and if that property actually is a URI, then continue
      kmod_install_list_uri = config_manager.mk_kmod_install_list_uri
      if config_manager.config_file_exists? && kmod_install_list_uri && !(kmod_install_list_uri =~ URI::regexp).nil?
        kernel_module_root = "/lib/modules/#{%x[uname -r].strip}/kernel/"
        install_list_uri = URI.parse(kmod_install_list_uri)
        vm_kernel_module_map = {}
        begin
          vm_kernel_module_map = JSON::parse(install_list_uri.read)
          logger.debug "received a TCE install list of '#{vm_kernel_module_map.inspect}'"
        rescue => e
          logger.debug "error while reading from '#{install_list_uri}' => #{e.message}"
          return
        end
        vm_kernel_modules = vm_kernel_module_map['kmod_list']

        #vm_kernel_modules = %W[fs/vmblock/vmblock.ko drivers/misc/vmsync.ko
        #      drivers/misc/vmci.ko drivers/net/vmxnet.ko fs/vmhgfs/vmhgfs.ko]

        modules_changed = false
        changed_modules = []
        lsmod_output = %x[sudo lsmod]
        vm_kernel_modules.each { |module_subpath|
          module_name = module_subpath.split("/")[-1].split('.')[0]
          name_plus_path = kernel_module_root + module_subpath
          module_regexp = Regexp.new(module_name)
          module_loaded = module_regexp.match(lsmod_output)
          is_open_vm_mod = @vmware_open_vm_tools_mods.include?(module_name)
          # if it's an open-vm-tools module but it's not a VMware-based virtual
          # environment, then remove that kernel module from the kernel, otherwise
          # install the module
          if is_open_vm_mod && (!Facter.is_virtual || !Facter.virtual == 'vmware')
            if module_loaded
              logger.debug "Removing module: #{module_name}"
              %x[sudo rmmod #{name_plus_path}] unless !mod_info || mod_info.length == 0
              changed_modules << module_name + "-"
              modules_changed = true unless modules_changed
            end
          else
            logger.debug "Installing module: #{module_name}"
            %x[sudo insmod #{name_plus_path}]
            changed_modules << module_name + "+"
            modules_changed = true unless modules_changed
          end
        }
        if modules_changed
          logger.info "Modules changed: #{changed_modules.join(", ")}"
          %x[sudo depmod -a]
        end
      end
    end

  end
end