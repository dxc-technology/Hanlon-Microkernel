# Manages the registration process (used by the rz_mk_control_server to
# register node with the Razor server on request or when facts change)
#
# @author Tom McSweeney

# adds a "require_relative" function to the Ruby Kernel if it
# doesn't already exist (used to deal with the fact that
# "require" is used instead of "require_relative" prior
# to Ruby v1.9.2)
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require 'rubygems'
require 'facter'
require 'yaml'
require_relative 'fact_manager'

class RzMkRegistrationManager

  attr_accessor :registration_uri

  def initialize(registration_uri, exclude_pattern, fact_manager, logger)
    @registration_uri = registration_uri
    @exclude_pattern = exclude_pattern
    @fact_manager = fact_manager
    @logger = logger
  end

  def register_node(last_state)
    # register facts with the server, regardless of whether or not they've
    # changed since the last registration
    register_with_server(last_state)
  end

  def register_node_if_changed(last_state)
    # register facts with the server, but only if they've changed since the
    # last registration
    register_with_server(last_state, true)
  end

  def register_with_server(last_state, only_if_changed = false)
    # load the current facts
    fact_map = Hash.new
    Facter.flush
    Facter.each { |name, value|
      fact_map[name.to_sym] = value if !(name =~ @exclude_pattern)
    }
    # if "only_if_changed" input argument (above) is false or current facts
    # are different from the last set of facts that were saved, then register
    # this node
    if !only_if_changed || fact_manager.facts_have_changed?(fact_map) then
      # build a JSON string from a Hash map containing the hostname, facts, and
      # the last_state
      json_hash = { }
      json_hash["@uuid"] = fact_map[:hostname]
      json_hash["@attributes_hash"] = fact_map
      json_hash["@last_state"] = last_state
      json_string = JSON.generate(json_hash)
      # and send that string to the service listening at the "Registration URI"
      # (this will register the node with the server at that URI)
      uri = URI @registration_uri
      puts "Sending new factMap to '" + uri.to_s + "' => " + json_string
      response = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      # if we were successful in registering with the server, save the current
      # facts as the previous facts
      case response
      when Net::HTTPSuccess then
        @fact_manager.save_facts_as_prev(fact_map)
      end
      # and construct the response back to the registration agent
      response['Content-Type'] = response['Content-Type']
      response.body = response.body
      # finally, if are debugging the server, output the body (as a string) to stdout
      # (which will typically be captured in a log file)
      logger.debug response.body
      # and return the response from the server to the caller
      response
    end
  end

  private :register_with_server

end