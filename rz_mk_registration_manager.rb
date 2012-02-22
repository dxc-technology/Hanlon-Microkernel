require 'rubygems'
require 'facter'
require 'yaml'

class RzMkRegistrationManager

  attr_accessor :registration_uri

  def initialize(registration_uri, exclude_pattern)
    @registration_uri = registration_uri
    @exclude_pattern = exclude_pattern
  end

  def register_node
    # load the current facts
    fact_map = Hash.new
    Facter.flush
    Facter.each { |name, value|
      fact_map[name.to_sym] = value if !(name =~ @exclude_pattern)
    }
    # build a JSON string from a Hash map containing the hostname, facts, and
    # the default_state
    json_hash = { }
    json_hash["@uuid"] = fact_map[:hostname]
    json_hash["@attributes_hash"] = fact_map
    json_hash["@last_state"] = @default_state
    json_string = JSON.generate(json_hash)
    # and send that string to the service listening at the "Registration URI"
    # (this will register the node with the server at that URI)
    uri = URI @registration_uri
    @logger.debug("Sending new factMap to '" + uri.to_s + "' => " + json_string)
    response = Net::HTTP.post_form(uri, 'json_hash' => json_string)
    # and construct the response back to the registration agent
    response['Content-Type'] = response['Content-Type']
    response.body = response.body
    # finally, if are debugging the server, output the body (as a string) into the log file
    @logger.debug(response.body)
    # and return the response from the server to the caller
    response
  end

end