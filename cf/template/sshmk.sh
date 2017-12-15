#!/bin/sh

cat /tmp/id_rsa0.pub >> /etc/ssh/keys-root/authorized_keys
cat /tmp/id_rsa1.pub >> /etc/ssh/keys-root/authorized_keys
rm /tmp/id_rsa0.pub
rm /tmp/id_rsa1.pub
