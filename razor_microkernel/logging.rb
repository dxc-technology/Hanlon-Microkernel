
require "logger"
require "razor_microkernel/rz_mk_configuration_manager"

LOG_LEVEL = Logger::DEBUG
LOG_MAX_SIZE = 2048576
LOG_MAX_FILES = 10

# Module used for all logging. Needs to be included in any Razor Microkernel class that needs logging.
# Uses Ruby Logger but overrides and instantiates one for each object that mixes in this module.
# It auto prefixes each log message with classname and method from which it was called using progname
module RazorMicrokernel::Logging

  # [Hash] holds the loggers for each instance that includes it
  @loggers = {}

  # grab a reference to the configuration manager, use it to determine what level to log at (below)
  @config_manager = (RazorMicrokernel::RzMkConfigurationManager).instance

  # Returns the logger object specific to the instance that called it
  def logger
    classname = self.class.name
    methodname = caller[0][/`([^']*)'/, 1]
    @logger ||= RazorMicrokernel::Logging.logger_for(classname, methodname)
    @logger.progname = "#{classname}\##{methodname}"
    @logger
  end

  # Singleton override that returns a logger for each specific instance
  class << self

    def get_log_path
      if !RZ_MK_LOG_PATH
        "/var/log/rz_mk_common.log"
      end
      RZ_MK_LOG_PATH
    end

    def get_log_level
      if !@config_manager.mk_log_level
        return @config_manager.default_mk_log_level
      end
      @config_manager.mk_log_level
    end

    # Returns specific logger instance from loggers[Hash] or creates one if it doesn't exist
    def logger_for(classname, methodname)
      @loggers[classname] ||= configure_logger_for(classname, methodname)
    end

    # Creates a logger instance
    def configure_logger_for(classname, methodname)
      logger = Logger.new(get_log_path, shift_age = LOG_MAX_FILES, shift_size = LOG_MAX_SIZE)
      logger.level = get_log_level
      logger
    end
  end

end
