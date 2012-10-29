#!/bin/sh

rm -rf original-iso-files extract tmp newiso

# get a copy of the files from the original ISO
if [ ! -d /tmp/cdrom ]; then
    mkdir /tmp/cdrom
fi
mount Core-current.iso /tmp/cdrom -o loop
mkdir original-iso-files
cp -a /tmp/cdrom/boot original-iso-files/
umount /tmp/cdrom

# extract the boot/core.gz file from that directory
mkdir extract
cd extract
zcat ../original-iso-files/boot/core.gz | cpio -i -H newc -d

# copy the resulting files over to a temporary directory (which we will
# use to build a new core.gz file for a new ISO
cd ..
mkdir tmp
cd tmp
cp -rp ../extract/* .

# unpack the dependency files that were extracted earlier (these files were
# built from the current contents of the Razor-Microkernel project using the
# build-dependency-files.sh shell script, which is part of that same project)
for file in mk-open-vm-tools.tar.gz razor-microkernel-overlay.tar.gz mcollective-setup-files.tar.gz ssh-setup-files.tar.gz; do
  # all of these files may not exist for all Microkernels, so only try to unpack
  # the files that do exist
  if [ -r ../dependencies/$file ]; then
    tar zxvf ../dependencies/$file
  fi
done

cd ..
mkdir newiso
cp -rp original-iso-files/boot newiso
sed -i "s/timeout 300/timeout 100/" newiso/boot/isolinux/isolinux.cfg
