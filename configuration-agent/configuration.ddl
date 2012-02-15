metadata  :name         => "Configuration Agent",
          :description  => "Razor Microkernel Configuration Agent",
          :author       => "Tom McSweeney",
          :license      => "Apache v2",
          :version      => "1.0",
          :url          => "http://www.emc.com",
          :timeout      => 30

action "set_registration_url",
      :description => "Set the URL that will be used for Registration" do

    display :always  # supported in 0.4.7 and newer only
 
    input :URI,
          :prompt      => "URI",
          :description => "The URI to use for Registration",
          :type        => :string,
          :validation  => '/^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.([a-z]{2,5}|[0-9]{1,3})(:[0-9]{1,5})?(\/.*)?$/ix',
          :optional    => false,

    output :Response,
          :description => "The response from the Registration Servlet",
          :display_as  => "Response"

    output :Time,
          :description => "The time that the response was sent back at",
          :display_as  => "Time"

end
