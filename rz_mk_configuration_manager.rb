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

  attr_reader :mk_checkin_interval
  attr_reader :mk_checkin_skew
  attr_reader :mk_uri
  attr_reader :mk_fact_excl_pattern
  attr_reader :mk_register_path # : /project_razor/api/node/register
  attr_reader :mk_checkin_path # checkin: /project_razor/api/node/checkin
  # mk_log_level should be 'Logger::FATAL', 'Logger::ERROR', 'Logger::WARN',
  # 'Logger::INFO', or 'Logger::DEBUG' (default is 'Logger::ERROR')
  attr_reader :mk_log_level
  attr_reader :default_mk_log_level
  
  def initialize
    @default_mk_log_level = Logger::INFO
    @mk_config_file = '/tmp/mk_conf.yaml'
  end

  def mk_config_has_changed?(new_mk_config_map, logger = nil)
    return true if !File.exists?(@mk_config_file)
    logger.debug("File exists; check to see if the config has changed") if logger
    old_mk_config_map = YAML::load(File.open(@mk_config_file, 'r'))
    return_val = old_mk_config_map != new_mk_config_map
    logger.debug("mk_config_has_changed? => #{return_val}") if logger
    return_val
  end

  def save_mk_config(mk_config_map, logger = nil)
    logger.debug "saving microkernel controller configuration to #{@mk_config_file}" if logger
    File.open(@mk_config_file, 'w') { |file|
      YAML::dump(mk_config_map, file)
    }
    load_config_vals(mk_config_map, logger)
  end

  def config_file_exists?
    File.exists?(@mk_config_file)
  end

  def load_current_config(logger = nil)
    mk_conf = YAML::load(File.open(@mk_config_file))
    load_config_vals(mk_conf, logger)
  end

  private
  def load_config_vals(mk_conf, logger = nil)
    @mk_checkin_interval = mk_conf['mk_checkin_interval']
    @mk_checkin_skew = mk_conf['mk_checkin_skew']
    @mk_uri = mk_conf['mk_uri']
    @mk_fact_excl_pattern = Regexp.new(mk_conf['mk_fact_excl_pattern'])
    @mk_register_path = mk_conf['mk_register_path']
    @mk_checkin_path = mk_conf['mk_checkin_path']
    case mk_conf['mk_log_level']
      when "Logger::FATAL"
        @mk_log_level = Logger::FATAL
      when "Logger::ERROR"
        @mk_log_level = Logger::ERROR
      when "Logger::WARN"
        @mk_log_level = Logger::WARN
      when "Logger::INFO"
        @mk_log_level = Logger::INFO
      when "Logger::DEBUG"
        @mk_log_level = Logger::DEBUG
      else
        logger.debug "Unrecognized mk_log_level => #{mk_conf['mk_log_level']}, setting to default" if logger
        @mk_log_level = default_mk_log_level
    end
  end

end