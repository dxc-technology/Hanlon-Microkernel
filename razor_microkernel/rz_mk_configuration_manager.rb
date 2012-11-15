# Used to manage the Microkernel Controller configuration (methods in this Module are called from both)
# the WEBrick server and the Microkernel Controller itself.
#
#

require 'yaml'
require 'singleton'

module RazorMicrokernel
  class RzMkConfigurationManager
    # make this class a singleton class (only want one)
    include Singleton

    MK_CONF_FILE = '/tmp/mk_conf.yaml'
    DEF_MK_GEM_MIRROR_URI = "http://localhost:2158/gem-mirror"
    DEF_MK_GEMLIST_URI = "http://localhost:2158/gem-mirror"
    
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
    attr_reader :mk_tce_mirror_port
    attr_reader :mk_tce_mirror_uri
    attr_reader :mk_tce_install_list_uri
    attr_reader :mk_kmod_install_list_uri
    attr_reader :mk_gem_mirror_uri
    attr_reader :mk_gemlist_uri

    def initialize
      @default_mk_log_level = Logger::INFO
    end

    def mk_config_has_changed?(new_mk_config_map)
      return true if !File.exists?(MK_CONF_FILE)
      old_mk_config_map = YAML::load(File.open(MK_CONF_FILE, 'r'))
      return_val = old_mk_config_map != new_mk_config_map
      return_val
    end

    def save_mk_config(mk_config_map)
      puts "Saving MK Configuration..."
      File.open(MK_CONF_FILE, 'w') { |file|
        YAML::dump(mk_config_map, file)
      }
      set_current_config(mk_config_map)
    end

    def config_file_exists?
      File.exists?(MK_CONF_FILE)
    end

    def load_current_config
      mk_conf = YAML::load(File.open(MK_CONF_FILE))
      set_current_config(mk_conf)
    end

    private
    def set_current_config(mk_conf)
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
          @mk_log_level = default_mk_log_level
      end
      @mk_tce_mirror_port = mk_conf['mk_tce_mirror_port']
      @mk_tce_mirror_uri = mk_conf['mk_tce_mirror_uri']
      @mk_tce_install_list_uri = mk_conf['mk_tce_install_list_uri']
      @mk_kmod_install_list_uri = mk_conf['mk_kmod_install_list_uri']
      if mk_conf['mk_gem_mirror_uri']
        @mk_gem_mirror_uri = mk_conf['mk_gem_mirror_uri']
      else
        @mk_gem_mirror_uri = DEF_MK_GEM_MIRROR_URI
      end
      if mk_conf['mk_gemlist_uri']
        @mk_gemlist_uri = mk_conf['mk_gemlist_uri']
      else
        @mk_gemlist_uri = DEF_MK_GEMLIST_URI
      end
    end

  end
end
