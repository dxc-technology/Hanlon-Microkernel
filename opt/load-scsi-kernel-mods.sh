#!/bin/sh

kernel_version=`uname -r`
mkdir -p /lib/modules/${kernel_version}/kernel/drivers/message/fusion
cp -p /usr/local/lib/modules/${kernel_version}/kernel/drivers/message/fusion/mptspi.ko.gz \
        /lib/modules/${kernel_version}/kernel/drivers/message/fusion/
cp -p /usr/local/lib/modules/${kernel_version}/kernel/drivers/message/fusion/mptscsih.ko.gz \
        /lib/modules/${kernel_version}/kernel/drivers/message/fusion/
cp -p /usr/local/lib/modules/${kernel_version}/kernel/drivers/message/fusion/mptbase.ko.gz \
        /lib/modules/${kernel_version}/kernel/drivers/message/fusion/
cp -p /usr/local/lib/modules/${kernel_version}/kernel/drivers/scsi/scsi_transport_spi.ko.gz \
        /lib/modules/${kernel_version}/kernel/drivers/scsi/scsi_transport_spi.ko.gz
insmod /lib/modules/${kernel_version}/kernel/drivers/message/fusion/mptbase.ko.gz
insmod /lib/modules/${kernel_version}/kernel/drivers/message/fusion/mptscsih.ko.gz
insmod /lib/modules/${kernel_version}/kernel/drivers/scsi/scsi_transport_spi.ko.gz 
insmod /lib/modules/${kernel_version}/kernel/drivers/message/fusion/mptspi.ko.gz 
