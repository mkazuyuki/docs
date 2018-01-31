#!/bin/sh

echo %%VMAPW%% | sudo -S sh -c "mv /tmp/after.local  /etc/init.d"
echo %%VMAPW%% | sudo -S sh -c "mv /tmp/before.local /etc/init.d"
echo %%VMAPW%% | sudo -S sh -c "chmod 744 /etc/init.d/after.local"
echo %%VMAPW%% | sudo -S sh -c "chmod 744 /etc/init.d/before.local"
echo %%VMAPW%% | sudo -S sh -c "chown root:root /etc/init.d/after.local"
echo %%VMAPW%% | sudo -S sh -c "chown root:root /etc/init.d/before.local"
