#!/bin/sh
. ./mk-build-lib.sh

# bring in the git derived version number...
. ./gitversion.sh

case $# in
    0)
        ;;                      # nothing to do

    1)
        if test x"$1" != x"${ISO_VERSION}"; then
            echo "overriding version from [${ISO_VERSION}] to [${1}]"
        fi
        ISO_VERSION="$1"        # override git version
        ;;

    *)
        echo "USAGE:  `echo $0 | awk -F'/' '{print $(NF)}' -` [VERSION]"
        echo "  where VERSION will override the version number of the ISO file from git"
        echo "  (it will be transformed into a filename that looks like:"
        echo '        rz_mk_dev-image_${ISO_VERSION}.iso'
        exit 1
esac

# We need to work out which of the set of tool names for building ISO images
# is used on this platform, and save it for later.
if exists genisoimage; then
    GENISO=genisoimage
elif exists mkisofs; then
    GENISO=mkisofs
else
    echo "Rebuilding the ISO image requires genisoimage or mkisofs."
    exit 1
fi

# We run the guest busybox using the host platform toolchain, so we should
# test if it works or not.  We can't use a host busybox because some platforms
# *cough* Ubuntu *cough* don't ship the depmod applet.
#
# This invocation is enough to run the guest Busybox on a 32-bit or 64-bit
# kernel, without needing to depend on host libraries matching the guest, or
# chroot, or anything super-fancy like that.
BUSYBOX="env LD_LIBRARY_PATH=$PWD/tmp/lib:$LD_LIBRARY_PATH LD_PRELOAD="
BUSYBOX="${BUSYBOX} $PWD/tmp/lib/ld-linux.so.2 $PWD/tmp/bin/busybox"
if ! ${BUSYBOX} true; then
    echo "It looks like I can't Unable to locate a working busybox for depmod!"
    echo "I tried the TCL busybox too, and it failed even with chroot."
    echo "If you see 'No such file or directory' above you probably need to install"
    echo "the 32-bit libc on your machine!"
    exit 1
fi

ISO_NAME=rz_mk_dev-image.${ISO_VERSION}.iso
DIR_NAME=`pwd`
set -x
# build the YAML file in the Microkernel's filesystem that will be used to
# display this same version information during boot
./add_version_to_mk_fs.rb tmp ${ISO_VERSION}

# Run depmod and ldconfig on the tmp directory, preparing it for construction
# of a bootable core.gz file in the event we added kernel modules or shared
# libraries in our unpacking.
#
# We also replace an absolute symlink in the module directory with a relative
# symlink, to allow depmod to correctly follow it without having to chroot.
#
# This is entirely compatible, but not done upstream, unfortunately.
kernelver="$(ls ${DIR_NAME}/extract/lib/modules)"
rm -f tmp/lib/modules/${kernelver}/kernel.tclocal
ln -s ../../../usr/local/lib/modules/${kernelver}/kernel \
    tmp/lib/modules/${kernelver}/kernel.tclocal

${BUSYBOX} depmod -a -b ${DIR_NAME}/tmp ${kernelver}
/sbin/ldconfig -r ${DIR_NAME}/tmp

# build the new core.gz file (containing the contents of the tmp directory)
cd tmp
find | cpio -o -H newc | gzip -2 > ../core.gz
cd ..
# compress the file and copy it to the correct location for building the ISO
advdef -z4 core.gz 
cp -p core.gz newiso/boot/
# build the YAML file needed for use in Razor, place it into the root of the
# ISO filesystem
./build_iso_yaml.rb newiso ${ISO_VERSION} boot/vmlinuz boot/core.gz
# finally, build the ISO itself from the newiso directory
"${GENISO}" -l -J -R -V TC-custom                           \
    -no-emul-boot -boot-load-size 4 -boot-info-table        \
    -b boot/isolinux/isolinux.bin                           \
    -c boot/isolinux/boot.cat                               \
    -o "${ISO_NAME}" newiso
