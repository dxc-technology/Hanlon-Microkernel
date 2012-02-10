# this is rz_mk_controller.rb
# it does nothing really useful at the moment

require 'logger'
require 'rubygems'
require 'facter'
require 'yaml'
require 'json'

registrationURLFile = '/var/run/registrationURL.txt'

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
    # construct a hash map of the facts gathered by Facter
    factMap = Hash.new
    Facter.each { |name, value|
        factMap[name.to_sym] = value
    }
    # compare the existing facts with those previously sent to the
    # registration URL
    factMapChanged = false
    if File.exists?('/var/run/facterOut.yaml') then
      oldFactMap = nil
      File.open('/var/run/facterOut.yaml', 'r') { |file|
        oldFactMap = YAML::load(file)
      }
      factMapChanged = !(factMap == oldFactMap)
    else
      # file does not exist yet, so will have to create it
      factMapChanged = true
    end
    if factMapChanged then
      File.open('/var/run/facterOut.yaml', 'w') { |file|
        YAML::dump(factMap, file)
      }
      mylog.debug("factMap changed, send new factMap to '" + registrationURL + "' => " +
                      JSON.generate(factMap))
    else
      mylog.debug("factMap unchanged, no update required")
    end
  else
    mylog.debug("file #{registrationURLFile} does not exist yet")
  end
  mylog.info "sleeping for 60 seconds..."
  sleep(60)
end
