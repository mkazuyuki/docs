#!/bin/sh
# ----------------------------------
# Make NIC-A on ESXi-B and NIC-E on ESXi-B Link Up
# ----------------------------------

esxcfg-vswitch iSCSI_vswitch -L vmnic_100600
esxcfg-vswitch iSCSI_vswitch -L vmnic_110600
