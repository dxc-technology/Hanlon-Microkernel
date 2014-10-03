#!/bin/sh

kernel_version=`uname -r`

insmod /usr/local/lib/modules/${kernel_version}/kernel/drivers/message/fusion/mptbase.ko.gz
insmod /usr/local/lib/modules/${kernel_version}/kernel/drivers/message/fusion/mptscsih.ko.gz
insmod /usr/local/lib/modules/3.8.13-tinycore/kernel/drivers/scsi/scsi_transport_spi.ko.gz
insmod /usr/local/lib/modules/${kernel_version}/kernel/drivers/message/fusion/mptspi.ko.gz