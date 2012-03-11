#!/usr/bin/env ruby
#
# Used during the ISO building process to build a YAML file (iso-metadata.yaml) that
# will be saved in the directory named in the first command-line argument (which, for
# our Microkernel ISO files, will be at the root of the Microkernel ISO's' filesystem)
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

require 'yaml'

if ARGV.length != 2
  puts "USAGE: #{$0} DIR_NAME ISO_VERSION"
  puts "  (example #{$0} /tmp v0.2.1.0"
end

# take the first argument as the directory to create the YAML file in
dir_name = ARGV[0]

# if the named file doesn't exist or it does and it isn't a directory, then exit
if !File.exist?(dir_name) || !File.directory?(dir_name)
  puts "#{$0} Error:  '#{dir_name}' is not a directory"
  exit(-1)
end

# build the YAML file
yaml_hash = Hash.new
yaml_hash['iso_version'] = ARGV[1]
yaml_hash['kernel'] = 'vmlinuz'
yaml_hash['initrd'] = 'core.gz'
yaml_hash['iso_build_time'] = Time.now.utc

# and save it to the iso-metadata.yaml file in the specified directory
iso_filename = dir_name + File::SEPARATOR + 'iso-metadata.yaml'
File.open(iso_filename, 'w') { |file|
  YAML::dump(yaml_hash, file)
}
