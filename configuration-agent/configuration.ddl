metadata  :name         => "Configuration Agent",
          :description  => "Razor Microkernel Configuration Agent",
          :author       => "Tom McSweeney",
          :license      => "Apache v2",
          :version      => "1.0",
          :url          => "http://www.emc.com",
          :timeout      => 2

action "set_registration_url",
      :description => "Set the URL that will be used for Registration" do

    display :always  # supported in 0.4.7 and newer only
 
    input :URL,
          :prompt      => "URL",
          :description => "The URL to use for Registration",
          :type        => :string,
          :validation  => '/^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$/ix',
          :optional    => false,

    output :URL,
          :description => "The URL received",
          :display_as  => "URL"
 
    output :time,
          :description => "The time the message was received",
          :display_as  => "Time"

end
