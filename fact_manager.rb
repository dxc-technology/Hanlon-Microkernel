require 'rubygems'
require 'facter'
require 'yaml'

class FactManager

  attr_reader :fact_map

  def initialize(prev_facts_file, exclude_pattern)
    @prev_facts_file = prev_facts_file
    @exclude_pattern = exclude_pattern
  end

  def facts_have_changed?
    # construct a hash map of the facts gathered by Facter (note call to
    # Facter.flush, which flushes the cache of Facter "facts")
    @fact_map = Hash.new
    Facter.flush
    Facter.each { |name, value|
      @fact_map[name.to_sym] = value if !(name =~ @exclude_pattern)
    }
    # compare the existing facts with those previously sent to the
    # registration URI
    fact_map_changed = false
    if File.exists?(@prev_facts_file)
      old_fact_map = nil
      File.open(@prev_facts_file, 'r') { |file|
        old_fact_map = YAML::load(file)
      }
      fact_map_changed = (fact_map != old_fact_map)
    else
      # file does not exist yet, so will have to create it
      fact_map_changed = true
    end
    # return flag indicating whether or not the Hash of facts has changed
    # since the last time this method was called
    fact_map_changed
  end

  def save_facts_as_prev
    File.open(@prev_facts_file, 'w') { |file|
      YAML::dump(@fact_map, file)
    }
  end

end