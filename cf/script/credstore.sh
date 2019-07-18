#!/bin/sh

ssh-keygen -R %%VMK1%%
ssh-keygen -R %%VMK2%%
ssh-keyscan %%VMK1%% >> ~/.ssh/known_hosts
ssh-keyscan %%VMK2%% >> ~/.ssh/known_hosts
perl /tmp/credstore_.pl
rm /tmp/credstore_.pl
