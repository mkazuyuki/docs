#!/bin/sh
# ----------------------------------
# Make NIC-A on ESXi-A and NIC-D on ESXi-B Link Down
# ----------------------------------

esxcfg-vswitch Mirror_vswitch -U vmnic_100101
esxcfg-vswitch Mirror_vswitch -U vmnic_110101
