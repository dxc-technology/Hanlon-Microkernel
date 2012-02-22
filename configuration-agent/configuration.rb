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

      action "set_mk_config" do
        validate :configuration, String
        # post configuration (as a JSON string) to the local WEBrick instance
        # (which should be running at port 2156)
        uri = URI "http://localhost:2156/setMkConfig"
        json_string = request[:configuration]
        res = Net::HTTP.post(uri, json_string)
        reply[:Response] = res.message
        reply[:Time] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      end

    end
  end
end
