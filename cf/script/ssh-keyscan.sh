#!/bin/sh

ssh-keygen -R %%VMK1%%
ssh-keygen -R %%VMK2%%
ssh-keyscan %%VMK1%% >> ~/.ssh/known_hosts
ssh-keyscan %%VMK2%% >> ~/.ssh/known_hosts
