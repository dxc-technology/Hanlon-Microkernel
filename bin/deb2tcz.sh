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
DEB_FILE="$1"
TCZ_FILE="$2"
INPUT=${DEB_FILE##*.}

[ -d "$PKGDIR" ] || mkdir -p "$PKGDIR"
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

make_tcz() {
	mkdir -p "$PKG"
	mkdir -p "$CFG"
	DATA_TAR=`ar t "$DEB_FILE" | grep data.tar.*`
	CONFIG_TAR=`ar t "$DEB_FILE" | grep control.tar.*`
	ar p "$DEB_FILE" "$DATA_TAR" > "$PKGDIR"/"$DATA_TAR"
	ar p "$DEB_FILE" "$CONFIG_TAR" > "$PKGDIR"/"$CONFIG_TAR"
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
		cp "$CFG/postinst" "$PKG/usr/local/postinst/${TCZ_FILE%.tcz}"
		SCRIPT='/usr/local/postinst/'${TCZ_FILE%.tce}' configure 2>/dev/null'
		setupStartupScript
		echo "${SCRIPT}" > "$PKG/usr/local/tce.installed/${TCZ_FILE%.tcz}"
		chmod 755 "$PKG/usr/local/tce.installed/${TCZ_FILE%.tcz}"
	fi
	
	cd "$PKGDIR"
	
	IMPORTMIRROR="http://distro.ibiblio.org/tinycorelinux/4.x/importscripts"   	
	wget -O "${TMPDIR}${TCZ_FILE}.deb2tcz" -cq "$IMPORTMIRROR"/"${TCZ_FILE}.deb2tcz" 2>/dev/null		
	if [ -f "${TMPDIR}${TCZ_FILE}.deb2tcz" ]
	then
		echo Merging Tiny Core custom start script for $TCZ_FILE: "${TCZ_FILE}.deb2tcz"
		setupStartupScript
		cat "${TMPDIR}${TCZ_FILE}.deb2tcz" >> "$PKG/usr/local/tce.installed/${TCZ_FILE%.tcz}"
		chmod 755 "$PKG/usr/local/tce.installed/${TCZ_FILE%.tcz}"
		rm "${TMPDIR}${TCZ_FILE}.deb2tcz"
	fi
	
	cd "$HERE"
	mksquashfs $PKG "$TCZ_FILE" -noappend
	rm -r "$PKGDIR"
}

[ -z "$TCZ_FILE" ] && echo "You must specify an extension name." && exit 1

[ -z "$1" ] && echo "You must specify a file."

if [ "$INPUT" != "deb" ] ; then
	echo "Only Debian packages work with this." 
	exit 1
fi

EXT=${TCZ_FILE##*.}
if [ `echo "$EXT" | grep "tcz"` 2>/dev/null ]; then
	make_tcz 
else 	
	echo "You need to specify a tcz  for the output file."
	exit 1
fi
	
if [ -f "$TCZ_FILE" ]; then
	echo "Success."
else
	echo "Something went wrong."
	exit 1
fi

set +x
set +v