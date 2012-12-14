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

ISO_NAME=rz_mk_dev-image.${ISO_VERSION}.iso
DIR_NAME=`pwd`
set -x
# build the YAML file in the Microkernel's filesystem that will be used to
# display this same version information during boot
./add_version_to_mk_fs.rb tmp ${ISO_VERSION}
# run chroot and ldconfig on the tmp directory (preparing it for construction
# of a bootable core.gz file)
#chroot ${DIR_NAME}/tmp depmod -a 3.0.21-tinycore
chroot ${DIR_NAME}/tmp depmod -a `ls ${DIR_NAME}/extract/lib/modules`
ldconfig -r ${DIR_NAME}/tmp
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
