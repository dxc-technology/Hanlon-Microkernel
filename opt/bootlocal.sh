#!/bin/sh
# put other system startup commands here

sudo /usr/local/etc/init.d/openssh start
sudo /usr/local/bin/rz_mk_init.rb
