#!/bin/sh
. ./mk-build-lib.sh

if ! test -f Core-current.iso; then
    echo "Can't find Core-current.iso in the current directory."
    echo "You should have extracted it from the build bundle."
    exit 1
fi

if test 0 -ne "$(id -u)"; then
    echo "You must have (fake)root privileges to unpack the directories"
    echo "the CPIO root file system has device nodes that you must be"
    echo "able to create, as well as setuid programs."
    echo ""
    echo "Using fakeroot or real root should behave equivalently, however"
    exit 1
fi


rm -rf original-iso-files extract tmp newiso
mkdir original-iso-files

# get a copy of the files from the original ISO
if exists 7z; then
    7z -o"original-iso-files" x Core-current.iso
else
    test -d /tmp/cdrom || mkdir -p /tmp/cdrom
    mount Core-current.iso /tmp/cdrom -o loop
    cp -a /tmp/cdrom/boot original-iso-files/
    umount /tmp/cdrom
fi

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
  if [ -r "../dependencies/${file}" ]; then
      echo "extracting ${file} into rootfs"
      tar zxf "../dependencies/${file}"
  fi
done

cd ..
mkdir newiso
cp -rp original-iso-files/boot newiso
sed -i "s/timeout 300/timeout 100/" newiso/boot/isolinux/isolinux.cfg

# Install the copyright and license files in the new ISO image
cp COPYING LICENSE newiso/
