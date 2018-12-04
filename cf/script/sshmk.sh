#!/bin/sh

a=`cat /tmp/id_rsa_vma_0.pub`; grep "$a" /etc/ssh/keys-root/authorized_keys
if [ $? != 0 ]; then
	cat /tmp/id_rsa_vma_0.pub >> /etc/ssh/keys-root/authorized_keys
fi

a=`cat /tmp/id_rsa_vma_1.pub`; grep "$a" /etc/ssh/keys-root/authorized_keys
if [ $? != 0 ]; then
	cat /tmp/id_rsa_vma_1.pub >> /etc/ssh/keys-root/authorized_keys
fi

a=`cat /tmp/id_rsa_iscsi_0.pub`; grep "$a" /etc/ssh/keys-root/authorized_keys
if [ $? != 0 ]; then
	cat /tmp/id_rsa_iscsi_0.pub >> /etc/ssh/keys-root/authorized_keys
fi

a=`cat /tmp/id_rsa_iscsi_1.pub`; grep "$a" /etc/ssh/keys-root/authorized_keys
if [ $? != 0 ]; then
	cat /tmp/id_rsa_iscsi_1.pub >> /etc/ssh/keys-root/authorized_keys
fi

rm /tmp/id_rsa_vma_0.pub
rm /tmp/id_rsa_vma_1.pub
rm /tmp/id_rsa_iscsi_0.pub
rm /tmp/id_rsa_iscsi_1.pub

esxcli system settings advanced set -i 0 -o /VMFS3/UseATSForHBOnVMFS5
esxcli system settings advanced list -o /VMFS3/UseATSForHBonVMFS5
