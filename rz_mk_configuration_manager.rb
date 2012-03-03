# Used to manage the Microkernel Controller configuration (methods in this Module are called from both)
# the WEBrick server and the Microkernel Controller itself.
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

require 'logger'
require 'yaml'
require 'json'
require 'singleton'

class RzMkConfigurationManager
  # make this class a singleton class (only want one)
  include Singleton

  def mk_config_has_changed?(new_mk_config_map, mk_config_file, logger = nil)
    return true if !File.exists?(mk_config_file)
    logger.debug("File exists; check to see if the config has changed") if logger
    old_mk_config_map = YAML::load(File.open(mk_config_file, 'r'))
    return_val = old_mk_config_map != new_mk_config_map
    logger.debug("mk_config_has_changed? => #{return_val}") if logger
    return_val
  end

  def save_mk_config(mk_config_map, mk_config_file, logger = nil)
    logger.debug "saving microkernel controller configuration to #{mk_config_file}"
    File.open(mk_config_file, 'w') { |file|
      YAML::dump(mk_config_map, file)
    }
  end

end