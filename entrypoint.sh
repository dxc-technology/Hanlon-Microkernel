#!/bin/bash

# ----------------------------------------------------------------------------
# Docker entrypoint script for Hanlon microkernel
# ----------------------------------------------------------------------------
set -e

declare -rx SCRIPT=${0##*/}

# Setup to allow access to BMC from within container
modprobe ipmi_si
ln -s /host-dev/ipmi* /dev

# Default application if nothing is specified
if [ -z "${1:0:1}" ]; then
	set -- start_mk
fi

case $1 in
  start_mk)
    set -- /bin/bash -c '/usr/local/bin/hnl_mk_init.rb && read -p "waiting..."'
    ;;
  help|info)
    set -- cat /README.md
    ;;
  version|ver)
    set -- cat /container-tmp-files/mk-version.yml | grep mk_version
esac

#echo "Executing: $@"
exec "$@"
