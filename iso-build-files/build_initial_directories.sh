#!/bin/sh

rm -rf original-iso-files extract tmp newiso

# get a copy of the files from the original ISO
if [ ! -d /tmp/cdrom ]; then
    mkdir /tmp/cdrom
fi
mount Core-current.iso /tmp/cdrom
mkdir original-iso-files
cp -a /tmp/cdrom/boot original-iso-files/
umount /tmp/cdrom

# extract the boot/core.gz file from that directory
mkdir extract
cd extract
zcat ../original-iso-files/boot/core.gz | cpio -i -H newc -d

# merge the results of this and our snapshot in the tmp subdirectory
cd ..
mkdir tmp
cd tmp
cp -rp ../extract/dev ../extract/mnt ../extract/proc ../extract/run \
    ../extract/sbin ../extract/sys ../extract/var .
tar zxvf ../orig-fs-snapshot/mc-linux-fs-snap.tar.gz

# unpack the dependency files that were extracted earlier (these files were
# built from the current contents of the Razor-Microkernel project using the
# build-dependency-files.sh shell script, which is part of that same project)
for file in fix-dmidecode-path-for-facter.tar.gz mk-open-vm-tools.tar.gz razor-microkernel-files.tar.gz; do
  tar zxvf ../dependencies/$file
done

cd ..
mkdir newiso
cp -rp original-iso-files/boot newiso
sed -i "s/timeout 300/timeout 100/" newiso/boot/isolinux/isolinux.cfg
