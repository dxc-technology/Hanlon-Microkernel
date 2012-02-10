# this is rz_mk_controller.rb
# it does nothing really useful at the moment

require 'logger'
require 'rubygems'
require 'facter'
require 'yaml'
require 'net/http'
require 'json'

registrationURLFile = '/tmp/registrationURL.txt'
previousFactsFile = '/tmp/facterOut.yaml'
excludeFactsPattern = /^uptime.*$/

mylog = Logger.new('/var/log/rz_mk_controller.log', 5, 1024*1024)
# mylog = Logger.new('/var/log/rz_mk_controller.log', 5, 'daily')
mylog.level = Logger::DEBUG

# can format the datetime for the messages this way
# mylog.datetime_format = "%Y-%m-%d %H:%M:%S"

# OR, can change the overall format this way (note how strftime is used
# within the defined proc to reformat the datetime argument)
mylog.formatter = proc do |severity, datetime, progname, msg|
  "(#{severity}) [#{datetime.strftime("%Y-%m-%d %H:%M:%S")}]: #{msg}\n"
end

loop do
  registrationURL = nil
  if File.exists?(registrationURLFile) then
    # open the registrationURL file and read it's contents (should be a URL)
    File.open(registrationURLFile, 'r') { |file|
      registrationURL = file.gets.chomp
    }
    # construct a hash map of the facts gathered by Facter (note call to
    # Facter.flush, which flushes the cache of Facter "facts")
    factMap = Hash.new
    Facter.flush
    Facter.each { |name, value|
      factMap[name.to_sym] = value if !(name =~ excludeFactsPattern)
    }
    # compare the existing facts with those previously sent to the
    # registration URL
    factMapChanged = false
    if File.exists?(previousFactsFile) then
      oldFactMap = nil
      File.open(previousFactsFile, 'r') { |file|
        oldFactMap = YAML::load(file)
      }
      factMapChanged = (factMap != oldFactMap)
    else
      # file does not exist yet, so will have to create it
      factMapChanged = true
    end
    if factMapChanged then
      File.open(previousFactsFile, 'w') { |file|
        YAML::dump(factMap, file)
      }
      jsonString = JSON.generate(factMap)
      uri = URI "#{registrationURL}/#{factMap[:hostname]}/#{state}"
      mylog.debug("factMap changed, send new factMap to '" + uri.to_s +
                      "' => " + jsonString)
      #res = Net::HTTP.post_form(uri, 'json_hash' => jsonString)
    else
      mylog.debug("factMap unchanged, no update required")
    end
  else
    mylog.debug("file #{registrationURLFile} does not exist yet")
  end
  mylog.info "sleeping for 60 seconds..."
  sleep(60)
end
