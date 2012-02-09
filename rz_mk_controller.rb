# this is rz_mk_controller.rb
# it does nothing really useful at the moment

require 'logger'
require 'rubygems'
require 'facter'
require 'json'

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
  factMap = Hash.new
  Facter.each { |name, value|
    factMap[name.to_sym] = value
  }
  mylog.debug(JSON.generate(factMap))
  mylog.info "sleeping for 60 seconds..."
  sleep(60)
end
