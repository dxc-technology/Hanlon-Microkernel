#!/bin/sh
#
# Used to build the overlay file needed to add the files from the
# Razor-Microkernel project to a Microkernel ISO image.  The file
# built by this script (along with any other gzipped tarfiles in
# the build_files subdirectory) should be placed into the "dependencies"
# subdirectory of the directory being used to build the Microkernel
# (where it will be picked up from by the build script).

# check to see if should re-use previous downloads (or not)
RE_USE_PREV_DL='no'
if [ $# -eq 1 ]
then
  case $1 in
  (--reuse-prev-dl) RE_USE_PREV_DL="yes" ;;
  (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
  esac
fi

# if not, then make sure we're starting with a clean (i.e. empty) build directory
if [ $RE_USE_PREV_DL = 'no' ]
then
  if [ ! -d tmp-build-dir ]; then
    # make a directory we can use to build our gzipped tarfile
    mkdir tmp-build-dir
  else
    # directory exists, so remove the contents
    rm -rf tmp-build-dir/*
  fi
fi

# initialize a couple of variables that we'll use later

TOP_DIR=`pwd`
TCL_MIRROR_URI='http://distro.ibiblio.org/tinycorelinux/4.x/x86/tcz'
TCL_ISO_URL='http://distro.ibiblio.org/tinycorelinux/4.x/x86/release/Core-current.iso'
RUBY_GEMS_URL='http://production.cf.rubygems.org/rubygems/rubygems-1.8.24.tgz'
#MCOLLECTIVE_URL='http://puppetlabs.com/downloads/mcollective/mcollective-1.2.1.tgz'
MCOLLECTIVE_URL='http://puppetlabs.com/downloads/mcollective/mcollective-2.0.0.tgz'

# create a folder to hold the gzipped tarfile that will contain all of
# dependencies

mkdir -p tmp-build-dir/build_dir/dependencies

# copy over the scripts that are needed to actually build the ISO into
# the build_dir (from there, they will be included into a single
# gzipped tarfile that can be unpacked and will contain almost all of
# the files/tools needed to build the Microkernel ISO)

cp -p iso-build-files/* tmp-build-dir/build_dir

# create a copy of the modifications to the DHCP client configuration that
# are needed for the Razor Microkernel Controller to find the appropriate
# Razor server for it's first checkin

mkdir -p tmp-build-dir/etc/init.d
cp -p etc/init.d/dhcp.sh tmp-build-dir/etc/init.d
mkdir -p tmp-build-dir/usr/share/udhcpc
cp -p usr/share/udhcpc/dhcp_mk_config.script tmp-build-dir/usr/share/udhcpc

# create copies of the files from this project that will be placed
# into the /usr/local/bin directory in the Razor Microkernel ISO

mkdir -p tmp-build-dir/usr/local/bin
cp -p rz_mk_*.rb tmp-build-dir/usr/local/bin

# create copies of the files from this project that will be placed
# into the /usr/local/lib/ruby/1.8/razor_microkernel directory in the Razor
# Microkernel ISO

mkdir -p tmp-build-dir/usr/local/lib/ruby/1.8/razor_microkernel
cp -p razor_microkernel/*.rb tmp-build-dir/usr/local/lib/ruby/1.8/razor_microkernel

# create copies of the MCollective agents from this project (will be placed
# into the /usr/local/tce.installed/$mcoll_dir/plugins/mcollective/agent
# directory in the Razor Microkernel ISO

file=`echo $MCOLLECTIVE_URL | awk -F/ '{print $NF}'`
mcoll_dir=`echo $file | cut -d'.' -f-3`
mkdir -p tmp-build-dir/usr/local/tce.installed/$mcoll_dir/plugins/mcollective/agent
cp -p configuration-agent/configuration.rb facter-agent/facteragent.rb \
    tmp-build-dir/usr/local/tce.installed/$mcoll_dir/plugins/mcollective/agent

# create a copy of the files from this project that will be placed into the
# /opt directory in the Razor Microkernel ISO; as part of this process will
# download the latest version of the gems in the 'gem.list' file into the
# appropriate directory to use in the build process (rather than including
# fixed versions of those gems as part of the Razor-Microkernel project)

mkdir -p tmp-build-dir/opt/gems
cp -p opt/bootsync.sh tmp-build-dir/opt
cp -p opt/gems/gem.list tmp-build-dir/opt/gems
cd tmp-build-dir/opt/gems
for file in `cat gem.list`; do
  if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f $file*.gem ]
  then
    gem fetch $file
  fi
done
cd $TOP_DIR

# create a copy of the local TCL Extension mirror that we will be running within
# our Microkernel instances

mkdir -p tmp-build-dir/tmp/tinycorelinux/4.x/x86/tcz
cp -p tmp/tinycorelinux/*.yaml tmp-build-dir/tmp/tinycorelinux
cd tmp-build-dir/tmp/tinycorelinux/4.x/x86/tcz
for file in `cat $TOP_DIR/extension-file.list`; do
  if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f $file ]
  then
    wget $TCL_MIRROR_URI/$file
    wget -q $TCL_MIRROR_URI/$file.md5.txt
    wget -q $TCL_MIRROR_URI/$file.info
    wget -q $TCL_MIRROR_URI/$file.list
    wget -q $TCL_MIRROR_URI/$file.dep
  fi
done
cd $TOP_DIR

# download a set of extensions that will be installed at boot; these files
# will be placed into the /tmp/builtin directory in the Microkernel ISO;
# the list of files downloaded (and loaded at boot) are contained in the
# file $TOP_DIR/additional-build-files/onboot.list

mkdir -p tmp-build-dir/tmp/builtin/optional
cd tmp-build-dir/tmp/builtin
cp -p $TOP_DIR/additional-build-files/onboot.lst .
cd optional
for file in `cat ../onboot.lst`; do
  if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f $file ]
  then
    wget $TCL_MIRROR_URI/$file
    wget -q $TCL_MIRROR_URI/$file.md5.txt
    wget -q $TCL_MIRROR_URI/$file.dep
  fi
done
cd $TOP_DIR

# download the ruby-gems distribution (will be installed during the boot
# process prior to starting the Microkernel initialization process)

cd tmp-build-dir/opt
file=`echo $RUBY_GEMS_URL | awk -F/ '{print $NF}'`
if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f $file ]
then
  wget $RUBY_GEMS_URL
fi
cd $TOP_DIR

# copy over a couple of initial configuration files that will be included in the
# /tmp and /etc directories of the Microkernel instance (the first two control the
# initial behavior of the Razor Microkernel Controller, the third disables automatic
# login of the tc user when the Microkernel finishes booting)

cp -p tmp/first_checkin.yaml tmp/mk_conf.yaml tmp-build-dir/tmp
cp -p etc/inittab tmp-build-dir/etc

# get a copy of the current Tiny Core Linux "Core" ISO

cd tmp-build-dir/build_dir
file=`echo $TCL_ISO_URL | awk -F/ '{print $NF}'`
if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f $file ]
then
  wget $TCL_ISO_URL
fi
cd $TOP_DIR

# download the MCollective, unpack it in the appropriate location, and
# add a couple of soft links

cd tmp-build-dir
file=`echo $MCOLLECTIVE_URL | awk -F/ '{print $NF}'`
mcoll_dir=`echo $file | cut -d'.' -f-3`
if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f $file ]
then
  wget $MCOLLECTIVE_URL
fi
cd usr/local/tce.installed
tar zxvf $TOP_DIR/tmp-build-dir/$file
cd $TOP_DIR/tmp-build-dir
rm usr/local/mcollective usr/local/bin/mcollectived 2> /dev/null
ln -s /usr/local/tce.installed/$mcoll_dir usr/local/mcollective
ln -s /usr/local/mcollective/bin/mcollectived usr/local/bin/mcollectived
cd $TOP_DIR

# add a soft-link in what will become the /usr/local/sbin directory in the
# Microkernel ISO (this fixes an issue with where Facter expects to find
# the 'dmidecode' executable)

mkdir -p tmp-build-dir/usr/sbin
rm tmp-build-dir/usr/sbin 2> /dev/null
ln -s /usr/local/sbin/dmidecode tmp-build-dir/usr/sbin 2> /dev/null

# create a gzipped tarfile containing all of the files from the Razor-Microkernel
# project that we just copied over, along with the files that were downloaded from
# the network for the gems and TCL extensions; place this gzipped tarfile into
# a dependencies subdirectory of the build_dir

cp -p additional-build-files/*.gz tmp-build-dir/build_dir/dependencies
cd tmp-build-dir
tar zcvf build_dir/dependencies/razor-microkernel-files.tar.gz usr etc opt tmp

# and create a gzipped tarfile containing the dependencies folder and the set
# of scripts that are used to build the ISO (so that all the user has to do is
# copy over this one file to a directory somewhere and unpack it and they will
# be ready to build the ISO

cd build_dir
tar zcvf $TOP_DIR/build-files/razor-microkernel-overlay.tar.gz *
cd $TOP_DIR
