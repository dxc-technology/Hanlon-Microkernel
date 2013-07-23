#!/bin/sh
# Original by Jason Williams
# Enhanced for Arm ports by Robert Shingledecker
# postinst / TC customization script support by Brian Smith
# Create tce/tcz from Debian package
# Usage: $ deb2tcz packagename.deb packaganame.tcz

set -x
set -v

HERE=`pwd`
PKGDIR="$HERE"/tmp/deb2tcz.1234
TMPDIR="$HERE"/tmp/deb2tcz.tmp
PKG="$PKGDIR"/pkg
CFG="$PKGDIR"/cfg
FILE="$1"
APPNAME="$2"
INPUT=${FILE##*.}

[ -d "$PKGDIR" ] || mkdir -p "$PKGDIR"
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

make_tcz() {
	mkdir -p "$PKG"
	mkdir -p "$CFG"
	DATA_TAR=`ar t "$FILE" | grep data.tar.*`
	CONFIG_TAR=`ar t "$FILE" | grep control.tar.*`
	ar p "$FILE" "$DATA_TAR" > "$PKGDIR"/"$DATA_TAR"
	ar p "$FILE" "$CONFIG_TAR" > "$PKGDIR"/"$CONFIG_TAR"
	tar xf "$PKGDIR"/"$DATA_TAR" -C "$PKG"
	tar xf "$PKGDIR"/"$CONFIG_TAR" -C "$CFG"
	[ -d "$PKG"/usr/share/doc ] && rm -r "$PKG"/usr/share/doc
	[ -d "$PKG"/usr/share/man ] && rm -r "$PKG"/usr/share/man
	[ -d "$PKG"/usr/share/menu ] && rm -r "$PKG"/usr/share/menu
	[ -d "$PKG"/usr/share/lintian ] && rm -r "$PKG"/usr/share/lintian
	cd "$PKG"
	find . -type d -empty | xargs rmdir > /dev/null 2>&1
	if [ -f "$CFG"/postinst ]; then
		mkdir -p "$PKG/usr/local/postinst"
		cp "$CFG/postinst" "$PKG/usr/local/postinst/${APPNAME%.tcz}"
		SCRIPT='/usr/local/postinst/'${APPNAME%.tce}' configure 2>/dev/null'
		setupStartupScript
		echo "${SCRIPT}" > "$PKG/usr/local/tce.installed/${APPNAME%.tcz}"
		chmod 755 "$PKG/usr/local/tce.installed/${APPNAME%.tcz}"
	fi
	
	cd "$PKGDIR"
	
	IMPORTMIRROR="http://distro.ibiblio.org/tinycorelinux/4.x/importscripts"   	
	wget -O "${TMPDIR}${APPNAME}.deb2tcz" -cq "$IMPORTMIRROR"/"${APPNAME}.deb2tcz" 2>/dev/null		
	if [ -f "${TMPDIR}${APPNAME}.deb2tcz" ]
	then
		echo Merging Tiny Core custom start script for $APPNAME: "${APPNAME}.deb2tcz"
		setupStartupScript
		cat "${TMPDIR}${APPNAME}.deb2tcz" >> "$PKG/usr/local/tce.installed/${APPNAME%.tcz}"
		chmod 755 "$PKG/usr/local/tce.installed/${APPNAME%.tcz}"
		rm "${TMPDIR}${APPNAME}.deb2tcz"
	fi
	
	mksquashfs pkg "$HERE"/"$APPNAME" -noappend
	cd "$HERE"
	rm -r "$PKGDIR"
}

[ -z "$APPNAME" ] && echo "You must specify an extension name." && exit 1

[ -z "$1" ] && echo "You must specify a file."

if [ "$INPUT" != "deb" ] ; then
	echo "Only Debian packages work with this." 
	exit 1
fi

EXT=${APPNAME##*.}
if [ `echo "$EXT" | grep "tcz"` 2>/dev/null ]; then
	make_tcz 
else 	
	echo "You need to specify a tcz  for the output file."
	exit 1
fi
	
if [ -f "$APPNAME" ]; then
	echo "Success."
else
	echo "Something went wrong."
	exit 1
fi

set +x
set +v