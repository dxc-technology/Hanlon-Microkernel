#!/bin/ash

# ----------------------------------------------------------------------------
# Docker entrypoint script for building Alpine packages
# ----------------------------------------------------------------------------
set -e

# Default application if nothing is specified
if [ -z "${1:0:1}" ]; then
	set -- start_apk_build
fi

case $1 in
  start_apk_build)
    set -- abuild-keygen -a -n; abuild unpack; abuild build; abuild rootpkg
    ;;
  help|info)
    set -- cat /README.md
    ;;
esac

#echo "Executing: $@"
exec "$@"