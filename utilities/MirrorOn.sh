#!/bin/sh
# ----------------------------------
# Make NIC-A on ESXi-A and NIC-D on ESXi-B Link UP
# ----------------------------------

esxcfg-vswitch Mirror_vswitch -L vmnic_100101
esxcfg-vswitch Mirror_vswitch -L vmnic_110101
