#!/bin/sh
#
# Used to build the bundle file needed to build a new version of the
# Razor Microkernel ISO (from the contents of the Razor Microkernel
# project and it's dependencies.  The file built by this script can
# be copied over to another directory (on another machine?) and unpacked.
# Once it has been unpacked, running the 'build_initial_directories.sh'
# script in that directory, followed by the 'rebuild_iso.sh' script,
# will result in a new ISO built from the current state of the this
# (Razor-Microkernel) project.
#
# Note:  the bundle file does not creaate a subdirectory, so a new, clean
#    directory should be used when unpacking the bundle file to build a
#    new version of the Microkernel ISO.

# define a function we can use to print out the usage for this script
usage()
{
cat << EOF

Usage: $0 OPTIONS

This script builds a gzipped tarfile containing all of the files necessary to
build an instance of the Razor Microkernel ISO.

OPTIONS:
   -h, --help                 print usage for this command
   -r, --reuse-prev-dl        reuse the downloads rather than downloading again
   -b, --builtin-list=FILE    file containing extensions to install as builtin
   -m, --mirror-list=FILE     file containing extensions to add to TCE mirror
   -p, --build-prod-image     build a production ISO (no openssh, no passwd)
   -d, --build-debug-image    build a debug ISO (enable automatic console login)
   -t, --tc-passwd=PASSWD     specify a password for the tc user

Note; currently, the default is to build a development ISO (which includes the
openssh.tcz extension along with the openssh/openssl configuration file changes
and the passwd changes needed to access the Microkernel image from the command
line or via the console).  Also note that only one of the '-p' and '-d' flags
may be specified and the '-t' option may not be used when building a production
ISO (using the '-p' flag).

EOF
}

# initialize a few variables to hold the options passed in by the user
BUILTIN_LIST=
MIRROR_LIST=
TC_PASSWD=
RE_USE_PREV_DL='no'
BUILD_PROD_ISO='no'
BUILD_DEBUG_ISO='no'

# options may be followed by one colon to indicate they have a required argument
if ! options=$(getopt -o hrb:m:pdt: -l help,reuse-prev-dl,builtin-list:,mirror-list:,build-prod-image,build-debug-image,tc-passwd: -- "$@")
then
    usage
    # something went wrong, getopt will put out an error message for us
    exit 1
fi
set -- $options

# loop through the command line arguments, parsing them as we go along
# (and shifting them off of the list of command line arguments as they,
# and their arguments if they have any, are parsed).  Note the use of
# the 'tr' and 'sed' commands when parsing the command arguments. The
# 'tr' command is used to remove the leading and trailing quotes from
# the arguments while the 'sed' command is used to remove the leading
# equals sign from the argument (if it exists).
while [ $# -gt 0 ]
do
  case $1 in
  -r|--reuse-prev-dl) RE_USE_PREV_DL='yes';;
  -b|--builtin-list) BUILTIN_LIST=`echo $2 | tr -d "'" | sed 's:^[=]\?\(.*\)$:\1:'`; shift;;
  -m|--mirror-list) MIRROR_LIST=`echo $2 | tr -d "'" | sed 's:^[=]\?\(.*\)$:\1:'`; shift;;
  -p|--build-prod-image) BUILD_PROD_ISO='yes';;
  -d|--build-debug-image) BUILD_DEBUG_ISO='yes';;
  -t|--tc-passwd)
    TC_PASSWD=`echo $2 | tr -d "'"`
    test1=`echo $TC_PASSWD | grep '^c-passwd='`
    if [ ! -z $test1 ]; then
      test=`echo $test1 | sed 's:^c-passwd=\(.*\)$:\1:'`
      echo -n "$0: WARNING, found value that looks like it includes part"
      echo -n " of the long argument name ($TC_PASSWD); should the password value be"
      echo " \"$test\" instead?"
    fi;
    test2=`echo $TC_PASSWD | grep '^='`
    if [ ! -z $test2 ]; then
      echo -n "$0: WARNING, password value with a leading '=' found"
      echo -n " ($test2), did you use an '=' between the short argument (-t)"
      echo " and its value? If so, you might not get the password you expect..."
    fi;
    shift;;
  -h|--help) usage; exit 0;;
  (--) shift; break;;
  (-*) echo "$0: error - unrecognized option $1" 1>&2; usage; exit 1;;
  esac
  shift
done

# if there are still arguments left, the syntax of the command is wrong
# (there were extra arguments given that don't belong)
if [ ! $# -eq 0 ]; then
  echo "$0: error - extra fields included in commmand; remaining args=$@" 1>&2; usage; exit 1
fi

# otherwise, sanity check the arguments that were parsed to ensure that
# the required arguments are present and the optional ones make sense
# (in terms of which optional arguments were given, and in what combination)
if [  -z $BUILTIN_LIST ] || [ -z $MIRROR_LIST ]; then
  echo "\nError (Missing Argument); the 'builtin-list' and 'mirror-list' must both be specified"
  usage
  exit 1
elif [ ! -r $BUILTIN_LIST ] || [ ! -r $MIRROR_LIST ]; then
  echo -n "\nError; the 'builtin-list' and 'mirror-list' values must both be readable files"
  echo " values parsed are as follows:"
  echo "\tbuiltin-list\t=> \"$BUILTIN_LIST\""
  echo "\tmirror-list\t=> \"$MIRROR_LIST\""
  usage
  exit 1
elif [ $BUILD_DEBUG_ISO = 'yes' ] && [ $BUILD_PROD_ISO = 'yes' ]; then
  echo "\nError; Only one of the '-d' and '-p' options should be specified"
  echo "     (ISO cannot be both a debug and production ISO)"
  usage
  exit 1
elif [ ! -z $TC_PASSWD ] && [ $BUILD_PROD_ISO = 'yes' ]; then
  echo "\nError; Only one of the '-t' and '-p' options should be specified"
  echo "     (Cannot specify a 'tc' password to use for a production ISO)"
  usage
  exit 1
fi

# the '-r' or '--reuse-prev-dl' flags were not given, then make sure we're
# starting with a clean (i.e. empty) build directory
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
OPEN_VM_TOOLS_URL='https://github.com/downloads/puppetlabs/Razor-Microkernel/mk-open-vm-tools.tar.gz'

# create a folder to hold the gzipped tarfile that will contain all of
# dependencies
mkdir -p tmp-build-dir/build_dir/dependencies

# copy over the scripts that are needed to actually build the ISO into
# the build_dir (from there, they will be included into a single
# gzipped tarfile that can be unpacked and will contain almost all of
# the files/tools needed to build the Microkernel ISO)
cp -p iso-build-files/* tmp-build-dir/build_dir
if [ $BUILD_PROD_ISO = 'yes' ]; then
  sed -i 's/ISO_NAME=rz_mk_dev-image/ISO_NAME=rz_mk_prod-image/' tmp-build-dir/build_dir/rebuild_iso.sh
elif [ $BUILD_DEBUG_ISO = 'yes' ]; then
  sed -i 's/ISO_NAME=rz_mk_dev-image/ISO_NAME=rz_mk_debug-image/' tmp-build-dir/build_dir/rebuild_iso.sh
fi

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
cp -p opt/boot*.sh tmp-build-dir/opt
cp -p opt/gems/gem.list tmp-build-dir/opt/gems
cd tmp-build-dir/opt/gems
for file in `cat gem.list`; do
  if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f $file*.gem ]
  then
    gem fetch $file
  fi
done
cd $TOP_DIR

# Create a gem mirror for running locally in the MK
mkdir -p tmp-build-dir/tmp/gem-mirror
cp -r tmp-build-dir/opt/gems tmp-build-dir/tmp/gem-mirror
gem generate_index -d tmp-build-dir/tmp/gem-mirror
sleep 5

# Add GemRC file to the ISO to use the mirror
mkdir -p tmp-build-dir/root
cp rz_mk_gemrc.yaml tmp-build-dir/root/.gemrc

# create a copy of the local TCL Extension mirror that we will be running within
# our Microkernel instances
mkdir -p tmp-build-dir/tmp/tinycorelinux/4.x/x86/tcz
cp -p tmp/tinycorelinux/*.yaml tmp-build-dir/tmp/tinycorelinux
for file in `cat $MIRROR_LIST`; do
  if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f tmp-build-dir/tmp/tinycorelinux/4.x/x86/tcz/$file ]
  then
    wget -P tmp-build-dir/tmp/tinycorelinux/4.x/x86/tcz $TCL_MIRROR_URI/$file
    wget -P tmp-build-dir/tmp/tinycorelinux/4.x/x86/tcz -q $TCL_MIRROR_URI/$file.md5.txt
    wget -P tmp-build-dir/tmp/tinycorelinux/4.x/x86/tcz -q $TCL_MIRROR_URI/$file.info
    wget -P tmp-build-dir/tmp/tinycorelinux/4.x/x86/tcz -q $TCL_MIRROR_URI/$file.list
    wget -P tmp-build-dir/tmp/tinycorelinux/4.x/x86/tcz -q $TCL_MIRROR_URI/$file.dep
  fi
done

# download a set of extensions that will be installed during the Microkernel
# boot process.  These files will be placed into the /tmp/builtin directory in
# the Microkernel ISO.  The list of files downloaded (and loaded at boot) are
# assumed to be contained in the file specified by the BUILTIN_LIST parameter
echo `pwd`
mkdir -p tmp-build-dir/tmp/builtin/optional
rm tmp-build-dir/tmp/builtin/onboot.lst 2> /dev/null
for file in `cat $BUILTIN_LIST`; do
  if [ $BUILD_PROD_ISO = 'no' ] || [ ! $file = 'openssh.tcz' ]; then
    if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f tmp-build-dir/tmp/builtin/optional/$file ]
    then
      wget -P tmp-build-dir/tmp/builtin/optional $TCL_MIRROR_URI/$file
      wget -P tmp-build-dir/tmp/builtin/optional -q $TCL_MIRROR_URI/$file.md5.txt
      wget -P tmp-build-dir/tmp/builtin/optional -q $TCL_MIRROR_URI/$file.dep
    fi
    echo $file >> tmp-build-dir/tmp/builtin/onboot.lst
  elif [ $BUILD_PROD_ISO = 'yes' ] && [ -f tmp-build-dir/tmp/builtin/optional/$file ]
  then
    rm tmp-build-dir/tmp/builtin/optional/$file
    rm tmp-build-dir/tmp/builtin/optional/$file.md5.txt 2> /dev/null
    rm tmp-build-dir/tmp/builtin/optional/$file.dep 2> /dev/null
  fi
done

# download the ruby-gems distribution (will be installed during the boot
# process prior to starting the Microkernel initialization process)
file=`echo $RUBY_GEMS_URL | awk -F/ '{print $NF}'`
if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f tmp-build-dir/opt/$file ]
then
  wget -P tmp-build-dir/opt $RUBY_GEMS_URL
fi

# copy over a couple of initial configuration files that will be included in the
# /tmp and /etc directories of the Microkernel instance (the first two control the
# initial behavior of the Razor Microkernel Controller, the third disables automatic
# login of the tc user when the Microkernel finishes booting)
  cp -p tmp/first_checkin.yaml tmp-build-dir/tmp
if [ $BUILD_DEBUG_ISO = 'yes' ]
then
  # if we're building a "debug" bundle, then copy over a microkernel configuration
  # file that will enable logging of DEBUG messages from the start
  cp -p tmp/mk_conf_debug.yaml tmp-build-dir/tmp/mk_conf.yaml
else
  # else copy over a file that will only enable logging of INFO/ERROR messages
  # from the start
  cp -p tmp/mk_conf.yaml tmp-build-dir/tmp
fi
cp -p etc/inittab tmp-build-dir/etc
# check to see if we're building a "Debug ISO"; if so, use sed to modify the inittab
# file we just copied over so that re-enables autologin
if [ $BUILD_DEBUG_ISO = 'yes' ]; then
  AUTO_LOGIN_STR='-nl /sbin/autologin'
  OLD_INITTAB_TTY1_PAT='^\(tty1.*\)\(38400 tty1\)$'
  sed -i "s/$OLD_INITTAB_TTY1_PAT/\1$(echo $AUTO_LOGIN_STR | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g') \2/" tmp-build-dir/etc/inittab
fi

# get a copy of the current Tiny Core Linux "Core" ISO
file=`echo $TCL_ISO_URL | awk -F/ '{print $NF}'`
if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f tmp-build-dir/build_dir/$file ]
then
  wget -P tmp-build-dir/build_dir $TCL_ISO_URL
fi

# download the MCollective, unpack it in the appropriate location, and
# add a couple of soft links
file=`echo $MCOLLECTIVE_URL | awk -F/ '{print $NF}'`
mcoll_dir=`echo $file | cut -d'.' -f-3`
if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f tmp-build-dir/$file ]
then
  wget -P tmp-build-dir $MCOLLECTIVE_URL
fi
cd tmp-build-dir/usr/local/tce.installed
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

# copy over a few additional dependencies (currently, this includes the
# following files:
#   1. ssh-setup-files.tar.gz -> contains the setup files needed for the
#         SSH/SSL (used for development access to the Microkernel); if
#         the '--build-prod-image' flag is set, then this file will be skipped
#   2. mcollective-setup-files.tar.gz -> contains the setup files needed for
#         running the mcollective daemon
#   3. mk-open-vm-tools.tar.gz -> contains the files needed for the
#         'open_vm_tools.tcz' extension
#   4. the etc/passwd and etc/shadow files from the Razor-Microkernel project
#         (note; if this is a production system then the etc/shadow-nologin
#         file will be copied over instead of the etc/shadow file (to block
#         access to the Microkernel from the console)
cp -p additional-build-files/*.gz tmp-build-dir/build_dir/dependencies
file=`echo $OPEN_VM_TOOLS_URL | awk -F/ '{print $NF}'`
if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f tmp-build-dir/build_dir/dependencies/$file ]
then
  wget -P tmp-build-dir/build_dir/dependencies $OPEN_VM_TOOLS_URL
fi

# Copy over the etc/passwd file to the tmp-build-dir/etc directory.
# If we're building a production system, development system, also copy over the
# etc/shadow file to the same directory.  If it's a production system we're
# building the ISO for, then copy over the etc/shadow-nologin file instead
# (and remove the SSH setup files from the files we just copied over to the
# dependencies directory)
cp -p etc/passwd tmp-build-dir/etc
if [ $BUILD_PROD_ISO = 'no' ]; then
  cp -p etc/shadow tmp-build-dir/etc
  # if a password for the tc user was passed in (using the -t or --tc-passwd flag)
  # then use it to replace the default password for the tc user in the shadow
  # password file we're burning into the ISO here (requires that openssl be installed
  # locally for this to work)
  if [ ! -z $TC_PASSWD ]; then
    echo "changing password for 'tc' user to $TC_PASSWD"
    NEW_PWD_ENTRY=`echo $TC_PASSWD | openssl passwd -1 -stdin`
    # use sed to replace the default password with the new one generated (above)
    # (but remember, need to escape the replacement string for use with sed first,
    # which is what the "$(echo ... | sed -e ...)" part of this command does; it
    # escapes any '\', '/', and '&' characters in the $NEW_PWD_ENTRY string so that
    # they will be passed as literals during replacement instead of being used as
    # part of the surrounding sed command)
    sed -i "s/^\(tc:\)[^\:]*\(.*\)/\1$(echo $NEW_PWD_ENTRY | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')\2/" tmp-build-dir/etc/shadow
  fi
else
  cp -p etc/shadow-nologin tmp-build-dir/etc/shadow
  rm tmp-build-dir/build_dir/dependencies/ssh-setup-files.tar.gz
fi

# get the latest util-linux.tcz, then extract the two executables that
# we need from that file (using the unsquashfs command)
file='util-linux.tcz'
if [ $RE_USE_PREV_DL = 'no' ] || [ ! -f tmp-build-dir/$file ]
then
  wget -P tmp-build-dir $TCL_MIRROR_URI/$file
fi
unsquashfs -f -d tmp-build-dir tmp-build-dir/util-linux.tcz `cat additional-build-files/util-linux-exec.lst`

# create a gzipped tarfile containing all of the files from the Razor-Microkernel
# project that we just copied over, along with the files that were downloaded from
# the network for the gems and TCL extensions; place this gzipped tarfile into
# a dependencies subdirectory of the build_dir
cd tmp-build-dir
tar zcvf build_dir/dependencies/razor-microkernel-overlay.tar.gz usr etc opt tmp root

# and create a gzipped tarfile containing the dependencies folder and the set
# of scripts that are used to build the ISO (so that all the user has to do is
# copy over this one file to a directory somewhere and unpack it and they will
# be ready to build the ISO
bundle_out_file_name='razor-microkernel-bundle-dev.tar.gz'
if [ $BUILD_PROD_ISO = 'yes' ]; then
  bundle_out_file_name='razor-microkernel-bundle-prod.tar.gz'
elif [ $BUILD_DEBUG_ISO = 'yes' ]; then
  bundle_out_file_name='razor-microkernel-bundle-debug.tar.gz'
fi

# and, finally, create our bundle file
if [ ! -d $TOP_DIR/build-files ]; then
    # make a directory we can use to build our gzipped tarfile
    mkdir $TOP_DIR/build-files
fi
cd build_dir
tar zcvf $TOP_DIR/build-files/$bundle_out_file_name *
cd $TOP_DIR
