module MCollective
  module Agent
    class Configuration<RPC::Agent
      metadata  :name         => "Configuration Agent",
                :description  => "Razor Microkernel Configuration Agent",
                :author       => "Tom McSweeney",
                :license      => "Apache v2",
                :version      => "1.0",
                :url          => "http://www.emc.com",
                :timeout      => 2

      action "set_registration_url" do
        validate :URL, String
        validate :URL, /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.([a-z]{2,5}|[0-9]{1,3})(:[0-9]{1,5})?(\/.*)?$/ix
        # Grab the URL and store it locally (will use it twice)
        registrationURL = request[:URL]
        # Output the URL to a local file
        File.open('/tmp/registrationURL.txt', 'w') { |file|
          file.puts(registrationURL)
        }
        # and echo back the URL and the time it was received to the sender
        reply[:URL] = registrationURL
        reply[:time] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      end
    end
  end
end
