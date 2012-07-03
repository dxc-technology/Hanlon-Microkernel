#!/usr/bin/env ruby
#
# Used during the ISO building process to build a YAML file (iso-metadata.yaml) that
# will be saved in the directory named in the first command-line argument (which, for
# our Microkernel ISO files, will be at the root of the Microkernel ISO's' filesystem)
#
#

require 'yaml'

if ARGV.length != 2
  puts "USAGE: #{$0} mk-fs-dir-name iso-version"
  puts "  (example #{$0} tmp v0.2.1.0"
end

# take the first argument as the directory to create the YAML file in
dir_name = ARGV[0]

# if the path passed as the directory name doesn't exist ()or it does and
# it isn't a directory), then exit
if !File.exist?(dir_name) || !File.directory?(dir_name)
  puts "#{$0} Error:  '#{dir_name}' is not a directory"
  exit(-1)
end

# second argument is the iso_version
iso_version = ARGV[1]

# dump out the Microkernel version into a file in the '/tmp' directory
# in the Microkernel filesystem (so that the Microkernel will have access
# to it during boot)
mk_version_hash = Hash.new
mk_version_hash['mk_version'] = iso_version
mk_version_filename = dir_name + File::SEPARATOR + 'tmp' + File::SEPARATOR + 'mk-version.yaml'
File.open(mk_version_filename, 'w') { |file|
  YAML::dump(mk_version_hash, file)
}
