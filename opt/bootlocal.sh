#!/bin/sh
# put other system startup commands here

sudo /usr/local/bin/load_kernel_modules.rb
sudo /usr/local/etc/init.d/openssh start
sudo gem install --no-ri --no-rdoc /opt/gems/bundler-1.0.21.gem
sudo /usr/local/bin/rz_mk_init.rb
