# Manages the registration process (used by the hnl_mk_control_server to
# register node with the Hanlon server on request or when facts change)
#
#

require 'rubygems'
require 'facter'
require 'yaml'
require 'hanlon_microkernel/hnl_mk_fact_manager'
require 'hanlon_microkernel/hnl_mk_hardware_facter'
require 'hanlon_microkernel/logging'

# set up a global variable that will be used in the HanlonMicrokernel::Logging mixin
# to determine where to place the log messages from this script (will be combined
# with the other log messages for the Hanlon Microkernel Controller)
HNL_MK_LOG_PATH = "/var/log/hnl_mk_controller.log"

module HanlonMicrokernel
  class HnlMkRegistrationManager

    # include the HanlonMicrokernel::Logging mixin (which enables logging)
    include HanlonMicrokernel::Logging

    attr_accessor :registration_uri

    def initialize(registration_uri, exclude_pattern, fact_manager)
      @registration_uri = registration_uri
      @exclude_pattern = exclude_pattern
      @fact_manager = fact_manager
      @hardware_facter = HnlMkHardwareFacter.instance
    end

    def register_node(last_state)
      # register facts with the server, regardless of whether or not they've
      # changed since the last registration
      register_with_server(last_state)
    end

    def register_node_if_changed(last_state)
      # register facts with the server, but only if they've changed since the
      # last registration
      response = register_with_server(last_state, true)
    end

    def register_with_server(last_state, only_if_changed = false)
      # load the current facts
      fact_map = Hash.new
      Facter.flush
      Facter.each { |name, value|
        fact_map[name.to_sym] = value if !@exclude_pattern || !(name =~ @exclude_pattern)
      }
      @hardware_facter.add_facts_to_map!(fact_map, @exclude_pattern)
      # if "only_if_changed" input argument (above) is false or current facts
      # are different from the last set of facts that were saved, then register
      # this node
      if !only_if_changed || @fact_manager.facts_have_changed?(fact_map)
        logger.debug "Build registration string"
        # build a JSON string from a Hash map containing the hostname, facts, and
        # the last_state
        json_hash = { }
        # Note: as of v0.7.0.0 of the Microkernel, the system is no longer identified using
        # a Microkernel-defined UUID value.  Instead, the Microkernel reports an array
        # containing "hw_id" information to the Hanlon server and the Hanlon server uses that
        # information to construct the UUID that the system will be (or is) mapped to.
        # The array passed through this "hw_id" key in the JSON hash is constructed by the
        # FactManager.  Currently, it includes a list of all of the network interfaces that
        # have names that look like 'eth[0-9]+', but that may change down the line.
        json_hash["mac_id"] = @fact_manager.get_mac_id_array
        json_hash["uuid"] = @fact_manager.get_uuid
        json_hash["attributes_hash"] = fact_map
        json_hash["last_state"] = last_state
        json_string = JSON.generate(json_hash)
        # and send that string to the service listening at the "Registration URI"
        # (this will register the node with the server at that URI)
        uri = URI @registration_uri
        header = {'Content-Type' => 'text/json'}
        http = Net::HTTP.new(uri.host, uri.port)
        logger.debug "Sending new factMap to '" + uri.to_s + "' => " + json_string
        request = Net::HTTP::Post.new(uri.request_uri, header)
        request.body = json_string
        # Send the request
        response = http.request(request)
        # if we were successful in registering with the server, save the current
        # facts as the previous facts
        case response
          when Net::HTTPSuccess then
            logger.info "Successfully registered node..."
            @fact_manager.save_facts_as_prev(fact_map)
        end
        # finally, if are debugging the server, output the body (as a string) to stdout
        # (which will typically be captured in a log file)
        logger.debug "response = #{response.inspect}"
        # and return the response from the server to the caller
        return response
      end
    end

    private :register_with_server

  end
end
