# DDL file for the configuration agent (defines the actions, inputs and outputs
# for this agent for the control node)
#
# @author Tom McSweeney

metadata  :name         => "Configuration Agent",
          :description  => "Razor Microkernel Configuration Agent",
          :author       => "Tom McSweeney",
          :license      => "Apache v2",
          :version      => "1.0",
          :url          => "http://www.emc.com",
          :timeout      => 30

action "send_mk_config",
      :description => "Send a new set of configuration parameters to the Microkernel agent" do

    display :always  # supported in 0.4.7 and newer only
 
    input :config_params,
          :prompt      => "Configuration",
          :description => "The configuration parameters (as a JSON-formatted Hash Map)",
          :type        => :string,
          :validation  => '/^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.([a-z]{2,5}|[0-9]{1,3})(:[0-9]{1,5})?(\/.*)?$/ix',
          :optional    => false,

    output :response,
          :description => "The response from the Registration Servlet",
          :display_as  => "Response"

    output :time,
          :description => "The time that the response was sent back at",
          :display_as  => "Time"

end
