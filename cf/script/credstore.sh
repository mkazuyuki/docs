#!/bin/sh

echo %%VMAPW%% | sudo -S sh -c "ssh-keygen -R %%VMK1%%"
echo %%VMAPW%% | sudo -S sh -c "ssh-keygen -R %%VMK2%%"
echo %%VMAPW%% | sudo -S sh -c "ssh-keyscan %%VMK1%% >> ~/.ssh/known_hosts"
echo %%VMAPW%% | sudo -S sh -c "ssh-keyscan %%VMK2%% >> ~/.ssh/known_hosts"
echo %%VMAPW%% | sudo -S sh -c "perl /tmp/credstore_.pl"
echo %%VMAPW%% | sudo -S sh -c "rm /tmp/credstore_.pl"
