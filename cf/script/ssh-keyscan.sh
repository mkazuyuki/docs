#!/bin/bash -x

if [ ! -d .ssh ]; then
	mkdir -m 700 .ssh
fi
if [ ! -e .ssh/id_rsa.pub ]; then
	ssh-keygen -f ~/.ssh/id_rsa -N ""
fi

ssh-keygen -R %%VMK1%%
ssh-keygen -R %%VMK2%%
ssh-keyscan %%VMK1%% >> ~/.ssh/known_hosts
ssh-keyscan %%VMK2%% >> ~/.ssh/known_hosts
