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
#

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
    # make this a singleton object (there should only be one in the system)
    include Singleton
    # and include the RazorMicrokernel::Logging mixin (which enables logging)
    include RazorMicrokernel::Logging

    # define a few constants that will be used later on
    PATHSEP = File::SEPARATOR
    KERNEL_MODULE_ROOT = "#{PATHSEP}lib#{PATHSEP}modules#{PATHSEP}" +
        "#{%x[uname -r].strip}#{PATHSEP}kernel"
    KMOD_GLOB_PATTERN_BASE = "#{KERNEL_MODULE_ROOT}#{PATHSEP}**#{PATHSEP}"
    OPEN_VM_TOOLS_MODS = %W[vmblock vmsync vmci vmxnet vmhgfs]

    def load_kernel_modules
      # get a reference to the Configuration Manager instance (a singleton)
      config_manager = (RazorMicrokernel::RzMkConfigurationManager).instance

      # if the config file exists and if the kmod_install_list_uri property exists in the configuration,
      # and if that property actually is a URI, then continue
      kmod_install_list_uri = config_manager.mk_kmod_install_list_uri
      if config_manager.config_file_exists? && kmod_install_list_uri && !(kmod_install_list_uri =~ URI::regexp).nil?

        # first, parse the URI and then retrieve the kmod_install_list (an array) from it
        install_list_uri = URI.parse(kmod_install_list_uri)
        kmod_install_list = {}
        begin
          kmod_install_list = JSON::parse(install_list_uri.read)
          logger.debug "received a TCE install list of '#{kmod_install_list.inspect}'"
        rescue => e
          logger.debug "error while reading from '#{install_list_uri}' => #{e.message}"
          return
        end

        # initialize a few variables that will be used within the loop...
        modules_changed = false
        changed_modules = []
        lsmod_output = %x[sudo lsmod]

        # determine which of these modules might already be installed (if any);
        # if there are modules that are already installed, then remove them
        rmmod_list = []
        kmod_install_list.each { |module_subpath|

          # get the name of the module from the full "module subpath"
          module_filename = module_subpath.split("/")[-1]
          module_name = module_filename.split('.')[0]

          # check to see if the module is already installed, if it is, then remove it
          module_regexp = Regexp.new(module_name)
          if module_regexp.match(lsmod_output)
            rmmod_list << module_name
            changed_modules << module_name + "-"
          end
        }
        # if there are modules to remove, then remove them (all at once in order
        # to avoid issues with dependencies)
        if rmmod_list.length > 0
          %x[sudo rmmod #{rmmod_list.join(' ')}]
        end

        # now that we know all of the existing modules (if any) are removed, we
        # can move on to (re-)installing them
        kmod_install_list.each { |module_subpath|

          # get the name of the module from the full "module subpath"
          module_filename = module_subpath.split("/")[-1]
          module_name = module_filename.split('.')[0]

          # determine the full path to the module under the KERNEL_MODULE_ROOT directory;
          # if the module is not found, or if more than one matching module is found, then
          # skip it (rather than trying to install something we can't find or something for which
          # there is more than one possible source).  Names can be disambiguated by providing a
          # more complete relative directory path as part of the name (names are assumed to
          # be relative to the KERNEL_MODULE_ROOT directory)
          name_plus_path_array = Dir.glob("#{KMOD_GLOB_PATTERN_BASE}#{module_name}.ko")
          unless name_plus_path_array && name_plus_path_array.length > 0
            # if we didn't find the module, log that fact and skip to the next one
            logger.warn "kernel module '#{module_name}.ko' not found under directory '#{KERNEL_MODULE_ROOT}'"
            next
          end
          if name_plus_path_array.length > 1
            # if we found more than one matching, log that fact and skip to the next one
            logger.warn "more than one kernel module matching the name '#{module_name}.ko' found under" +
                            " '#{KERNEL_MODULE_ROOT}', skipping installation of this (ambiguous) module"
            next
          end
          name_plus_path = name_plus_path_array[0]

          # if the module is a module from the open_vm_tools.tcz extension, then skip
          # installing it unless we are in a VMware-based virtual environment
          next unless !OPEN_VM_TOOLS_MODS.include?(module_name) ||
              (Facter.is_virtual && Facter.virtual == 'vmware')

          # if we've gotten this far, then it's safe to just install the module
          logger.debug "Installing module: #{name_plus_path}"
          %x[sudo insmod #{name_plus_path}]
          removed_mod_index = changed_modules.index(module_name + "-")
          if removed_mod_index
            changed_modules[removed_mod_index] = module_name + "/"
          else
            changed_modules << module_name + "+"
          end
          modules_changed = true unless modules_changed
        }
        if modules_changed
          logger.info "Modules changed: #{changed_modules.join(", ")}"
          %x[sudo depmod -a]
        end
      end
    end

  end
end
