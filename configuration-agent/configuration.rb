# The configuration agent (hosted on the managed nodes, works with the
# rz_web_server to save the new configuration to the filesystem on the
# Microkernel and restart the rz_mk_contoller)
#
#

require 'net/http'

module MCollective
  module Agent
    class Configuration<RPC::Agent
      metadata  :name         => "Configuration Agent",
                :description  => "Razor Microkernel Configuration Agent",
                :author       => "Tom McSweeney",
                :license      => "Apache v2",
                :version      => "1.0",
                :url          => "http://www.emc.com",
                :timeout      => 30

      action "send_mk_config" do
        validate :config_params, String
        # post configuration (as a JSON string) to the local WEBrick instance
        # (which should be running at port 2156)
        uri = URI "http://localhost:2156/setMkConfig"
        json_string = request[:config_params]
        res = Net::HTTP.post_form(uri, json_string)
        reply[:response] = res.message
        reply[:time] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      end

    end
  end
end
