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

      action "set_registration_uri" do
        validate :URI, String
        validate :URI, /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.([a-z]{2,5}|[0-9]{1,3})(:[0-9]{1,5})?(\/.*)?$/ix
        # post URI to a local WEBrick instance (should be running at port 2156)
        uri = URI "http://localhost:2156/registration"
        response = Net::HTTP.post_form(uri, 'registrationURI' => request[:URI])
        # and echo back the response from the WEBrick server (and the time that response
        # was sent back to the client)
        reply[:Response] = response.body.to_s
        reply[:Time] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      end
    end
  end
end
