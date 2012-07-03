#!/usr/bin/env ruby
#
# Used during the ISO building process to build a YAML file (iso-metadata.yaml) that
# will be saved in the directory named in the first command-line argument (which, for
# our Microkernel ISO files, will be at the root of the Microkernel ISO's' filesystem)
#
#

require 'yaml'
require 'digest/sha2'

def get_file_sha2_hash(path_to_file)
  if !File.exist?(path_to_file)
    return nil
  end
  file_h = Digest::SHA2.new(256)
  File.open(path_to_file, 'r') do |fh|
    while buffer = fh.read(1024)
      file_h << buffer
    end
  end
  file_h.to_s
end

if ARGV.length != 4
  puts "USAGE: #{$0} dir-name iso-version kernel-path initrd-path"
  puts "  (example #{$0} tmp v0.2.1.0 boot/vmlinuz boot/core.gz"
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

# third argument is the path to the kernel image (assumed to be under the directory
# passed as the first argument)
kernel_path = ARGV[2]
path_to_file = dir_name + File::SEPARATOR + kernel_path
unless (kernel_sha2 = get_file_sha2_hash(path_to_file))
  puts "#{$0} Error:  '#{path_to_file}' is not a file"
  exit(-2)
end

# and the fourth argument is the path to the initrd image (again, assumed to be under
# the directory passed as the first argument)
initrd_path = ARGV[3]
path_to_file = dir_name + File::SEPARATOR + initrd_path
unless (initrd_sha2 = get_file_sha2_hash(path_to_file))
  puts "#{$0} Error:  '#{path_to_file}' is not a file"
  exit(-3)
end


# build the YAML file
yaml_hash = Hash.new
yaml_hash['iso_version'] = iso_version
yaml_hash['kernel'] = kernel_path
yaml_hash['initrd'] = initrd_path
yaml_hash['hash_description'] = { "type" => "Digest::SHA2", "bitlen" => 256 }
yaml_hash['kernel_hash'] = kernel_sha2
yaml_hash['initrd_hash'] = initrd_sha2
yaml_hash['iso_build_time'] = Time.now.utc

# and save it to the iso-metadata.yaml file in the specified directory
iso_filename = dir_name + File::SEPARATOR + 'iso-metadata.yaml'
File.open(iso_filename, 'w') { |file|
  YAML::dump(yaml_hash, file)
}
