#!/bin/sh
# put other system startup commands here, the boot process will wait until they complete.
# Use bootlocal.sh for system startup commands that can run in the background 
# and therefore not slow down the boot process.
/usr/bin/sethostname box
sudo /usr/local/etc/init.d/openssh start
sudo gem install --no-ri --no-rdoc /opt/gems/bundler-1.0.21.gem
sudo /usr/local/bin/rz_mk_init.rb
/opt/bootlocal.sh &
