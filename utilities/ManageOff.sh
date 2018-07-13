#!/bin/sh
# ----------------------------------
# Make NIC-C on ESXi-A and NIC-F on ESXi-B Link Down
# ----------------------------------

esxcfg-vswitch vSwitch0 -U vmnic_100100
esxcfg-vswitch vSwitch0 -U vmnic_110100
