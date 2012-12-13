#!/bin/sh
#
# Build tool support library for Razor Microkernel

# A portable way to find out if a tool exists in the path.
exists () { (
    IFS=:
    for d in $PATH; do
      if test -x "$d/$1"; then return 0; fi
    done
    return 1
) }
