#!/bin/sh
# put other system startup commands here, the boot process will wait until they complete.
# Use bootlocal.sh for system startup commands that can run in the background 
# and therefore not slow down the boot process.

# first, install rubygems (from the gzipped tarfile included in the ISO)
prev_wd=`pwd`
rubygems_file=`ls /opt/rubygems*.tgz | awk -F/ '{print $NF}'`
rubygems_dir=`echo $rubygems_file | cut -d'.' -f-3`
sudo mkdir /opt/tmp-install-rubygems
cd /opt/tmp-install-rubygems
sudo tar zxvf ../$rubygems_file
cd $rubygems_dir
sudo ruby setup.rb
cd $prev_wd
sudo rm -rf /opt/tmp-install-rubygems

# then, initialize the Microkernel and start a few key services
/usr/bin/sethostname box
if [ -f /usr/local/etc/init.d/openssh ]
then
  sudo /usr/local/etc/init.d/openssh start
fi
sudo /usr/local/bin/rz_mk_init.rb
/opt/bootlocal.sh &
