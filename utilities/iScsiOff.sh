#!/bin/sh
# ----------------------------------
# Make NIC-B on ESXi-A and NIC-E on ESXi-B Link Down
# ----------------------------------

esxcfg-vswitch iSCSI_vswitch -U vmnic_100600
esxcfg-vswitch iSCSI_vswitch -U vmnic_110600
