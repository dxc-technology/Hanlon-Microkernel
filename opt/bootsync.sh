#!/bin/sh
# put other system startup commands here, the boot process will wait until they complete.
# Use bootlocal.sh for system startup commands that can run in the background 
# and therefore not slow down the boot process.

# install the IPMI kernel modules
sudo -u tc tce-load -i /tmp/tinycorelinux/4.x/x86/tcz/ipmi-kernel-mods.tcz 2>&1 | tee /tmp/ipmi-load.log
IPMI_MOD_DIR="/lib/modules/`uname -r`/kernel/drivers/char/ipmi"
for mod in ipmi_msghandler.ko ipmi_si.ko ipmi_devintf.ko ipmi_poweroff.ko ipmi_watchdog.ko; do
  sudo insmod ${IPMI_MOD_DIR}/$mod 2>&1 | tee -a /tmp/ipmi-load.log
done
sudo depmod -a

# and install the IPMI utilities (will need these during the
# Microkernel Controller initialization process to construct
# the hardware ID for the node)
sudo -u tc tce-load -i /tmp/tinycorelinux/4.x/x86/tcz/freeipmi.tcz 2>&1 | tee -a /tmp/ipmi-load.log
sudo -u tc tce-load -i /tmp/tinycorelinux/4.x/x86/tcz/openipmi.tcz 2>&1 | tee -a /tmp/ipmi-load.log
sudo -u tc tce-load -i /tmp/builtin/optional/readline.tcz 2>&1 | tee -a /tmp/ipmi-load.log
sudo -u tc tce-load -i /tmp/tinycorelinux/4.x/x86/tcz/ipmitool.tcz 2>&1 | tee -a /tmp/ipmi-load.log

# next, install rubygems (from the gzipped tarfile included in the ISO)
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

# load the kernel modules needed to access SCSI devices
sudo /opt/load-scsi-kernel-mods.sh

# and, finally, start a few key services and initialize the Microkernel
/usr/bin/sethostname box
if [ -f /usr/local/etc/init.d/openssh ]
then
  sudo /usr/local/etc/init.d/openssh start
fi
sudo /usr/local/bin/hnl_mk_init.rb
/opt/bootlocal.sh &
