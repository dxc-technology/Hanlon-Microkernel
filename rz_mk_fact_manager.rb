# Used to manage the facts gathered (using Facter) in the Microkernel
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

require 'rubygems'
require 'facter'
require 'yaml'

class RzMkFactManager

  attr_accessor :prev_facts_filename
  attr_reader :last_saved_timestamp

  def initialize(prev_facts_filename)
    @prev_facts_filename = prev_facts_filename
    @last_saved_timestamp = Time.at(0)
  end

  def facts_have_changed?(current_fact_map)
    # compare the existing facts with those previously saved to the YAML file
    fact_map_changed = false
    if File.exists?(@prev_facts_filename)
      old_fact_map = nil
      File.open(@prev_facts_filename, 'r') { |file|
        old_fact_map = YAML::load(file)
      }
      return (current_fact_map != old_fact_map)
    end
    # since file doesn't exist, the facts have changed (by definition)
    return true
  end

  def save_facts_as_prev(current_fact_map)
    File.open(@prev_facts_filename, 'w') { |file|
      YAML::dump(current_fact_map, file)
    }
    @last_saved_timestamp = Time.now
  end

end