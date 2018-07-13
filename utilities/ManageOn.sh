#!/bin/sh
# ----------------------------------
# Make NIC-C on ESXi-A and NIC-F on ESXi-B Link Up
# ----------------------------------

esxcfg-vswitch vSwitch0 -L vmnic_100100
esxcfg-vswitch vSwitch0 -L vmnic_110100
