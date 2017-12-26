#!/bin/sh

cat /tmp/id_rsa_vma_0.pub >> /etc/ssh/keys-root/authorized_keys
cat /tmp/id_rsa_vma_1.pub >> /etc/ssh/keys-root/authorized_keys
cat /tmp/id_rsa_iscsi_0.pub >> /etc/ssh/keys-root/authorized_keys
cat /tmp/id_rsa_iscsi_1.pub >> /etc/ssh/keys-root/authorized_keys
rm /tmp/id_rsa_vma_0.pub
rm /tmp/id_rsa_vma_1.pub
rm /tmp/id_rsa_iscsi_0.pub
rm /tmp/id_rsa_iscsi_1.pub
