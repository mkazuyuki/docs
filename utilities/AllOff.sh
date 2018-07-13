#!/bin/sh
# ----------------------------------
# Make NIC-A/B/C on ESXi-A and NIC-D/E/F on ESXi-B Link Down
# ----------------------------------

./ManageOff.sh
./iScsiOff.sh
./MirrorOff.sh
