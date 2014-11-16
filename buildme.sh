#!/bin/bash

for mod in be2net ipmi-kernel-mods ; do
		for file in $mod.tcz $mod.tcz.md5.txt ; do
				[ -f ./extra-driver-files/$file ] || \
						wget https://github.com/csc/Hanlon-Microkernel/releases/download/v2.0.0/$file -P ./extra-driver-files/
		done				
done

for mod in freeipmi-1.4.5 ipmitool-1.8.14 OpenIPMI-2.0.21 open-vm-tools-modules-3.8.13-tinycore ; do
		for file in $mod.tcz $mod.tcz.md5.txt ; do
				[ -f ./extra-extensions/$file ] || \
						wget https://github.com/csc/Hanlon-Microkernel/releases/download/v2.0.0/$file -P ./extra-extensions/
		done				
done

./build-bundle-file.sh --builtin-list additional-build-files/builtin-extensions.lst \
											 -a additional-build-files/addtnl-driver-mods.lst \
											 -m additional-build-files/mirror-extensions.lst \
											 -l additional-build-files/local-extensions.lst \
											 --build-debug-image \
											 --tc-passwd aoeu 2>&1

REL=118
cd tmp-build-dir/build_dir
fakeroot ./build_initial_directories.sh
fakeroot ./rebuild_iso.sh 2.0.0.$REL

# assuming hanlon is at same level as us
cd ../../../hanlon
bundle exec ./cli/hanlon image add -t mk -p ../Hanlon-Microkernel/tmp-build-dir/build_dir/hnl_mk_debug-image.2.0.0.$REL.iso
