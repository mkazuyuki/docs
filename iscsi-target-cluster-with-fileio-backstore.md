# Howto setup iSCSI Target Cluster on EXPRESSCLUSTER for Linux wtih fileio backstore 

----

This text descrives how to create iSCSI Target cluster (with fileio backstore) on EXPRESSCLUSTER for Linux.

----

## Revision histoory

2016.11.29 Miyamto Kazuyuki	1st issue

## Versions used
- RHEL7.2 x86_64
- ECX3.3.3-1

## Nodes configuration

| Role of the node		 | Host name | IP address      |
|--------------------------------|-----------|-----------------|
| Primary iSCSI Target Node	 | node-t1   | 192.168.137.131 |
| Secondary iSCSI Target Node	 | node-t2   | 192.168.137.132 |
| Primarry iSCSI Initiator Node  | node-i1   ||
| Secondary iSCSI Initiator Node | node-i2   ||

## Parameters

| Cluster Resources	   | Value			|
|--------------------------|----------------------------|
| FIP			   | 192.168.137.130		|
| Cluster Partition	   | /dev/sdb1			|
| Data Partition	   | /dev/sdb2			|
| WWN of iSCSI Target	   | iqn.2016-10.test.target:t1 |
| WWN of iSCSI Initiator 1 | iqn.2016-10.test.target:i1 |
| WWN of iSCSI Initiator 2 | iqn.2016-10.test.target:i2 |


## Procedure

### Installing OS and packages

On both iSCSI Target Nodes,

- Install RHEL7 and configure
	- hostname (e.g. node-t1, node-t2)
	- IP address (e.g. 192.168.137.131 for node-t1, 192.168.137.132 for node-t2)
	- block device for MD resoruce (e.g. /dev/sdb1 and /dev/sdb2).

- Install packages and EC licenses

		# yum install targetcli targetd
		# rpm -ivh expresscls.*.rpm
		# clplcnsc -i [*base-license-file*] -p BASE33
		# clplcnsc -i [*replicator-license-file*] -p REPL33

### Configuring iSCSI Target

### Configure EC

----
On the client PC,

- Open EXPRESSCLUSTER Builder ( http://[IP of a host]:29003/ )
- Configure the cluster which have no failover-group.

Add the failover-group for controlling iSCSI Target service.

- [Cluster Properties] > [Interconnect] tab > set one of [MDC] as [mdc1]
- Right click [Groups] in left pane then click [Add Group]
- Set [Name] as [*failover-iscsi*] then click [Next]
- Click [Next]
- Click [Next]
- Click [Add]
- Select [Type] as [mirror disk resource], set [Name] as [md1] then click [Next]
- Click [Next]
- Click [Next]
- Set

		[Mount Point] as [/mnt]
		[Data Partition Device Name] as [ /dev/sdb2 ]
		[Clsuter Partition Device Name] as [ /dev/sdb1 ]

- Click [OK]
- Click [Add]
- Select [Type] as [execute resource] then click [Next]
- Click [Next]
- Click [Next]
- Select start.sh then click [Edit]. Add below lines.

		echo "Starting iSCSI Target"
		systemctl start target
		echo "Started  iSCSI Target"

- Select stop.sh then click [Edit]. Add below lines.

		echo "Stopping iSCSI Target"
		systemctl stop target
		echo "Stopped   iSCSI Target"

- Click [OK]

<!--
- Click [Add]
- Select [Type] as [floatin IP resource] then click [Next]
- Set floating IP address as [ 192.168.137.130 ] 
- Click [OK]
-->

- Click [Finish]
- Click [File] > [Apply Configuration]
- Reboot node-t1, node-t2 and wait for the completion of starting of *failover-iscsi*

On node-t1, prepare block device for iSCSI Target and create iSCSI Target

- Start (iSCSI) target configuration tool

		# targetcli

- Create [ec-dp] as backstore

================================
<!-- To be revised from here -->
================================

		/> backstores/fileio create ec-dp /dev/NMP1


- Create WWN

		/> iscsi/ create iqn.2016-10.test.target:t1

- Create LUN with ec-dp

		/> iscsi/iqn.2016-10.test.target:t1/tpg1/luns create /backstores/block/ec-dp

- Create ACL

	- for node-i1

		/> iscsi/iqn.2016-10.test.target:t1/tpg1/acls create iqn.2016-10.test.initiator:i1

	- for node-i2

		/> iscsi/iqn.2016-10.test.target:t1/tpg1/acls create iqn.2016-10.test.initiator:i2

- Finish configuring iSCSI Target then configuration is saved.

		/> exit

- Copy the saved configuration to another node.

		# scp /etc/target/saveconfig.json tgt-node2:/etc/target/

- De-activate the mirror disk

		# clpmdctrl -d md1

----------
On node-t2,

- Activate the mirror disk

		# clpmdctrl -a -nomount md1

- Restore iSCSI Target configuration

		# targetcli restoreconfig

## Appendix

On node-i1

- Edit iSCSI Initiator configuration.

		# vi /etc/iscsi/initiatorname.iscsi

- Re-write "InitiatorName" and save it.

		InitiatorName=iqn.2016-10.test.initiator:i1

- Restart iSCSI Initiator (restart iscsid due to rename of initiator)

		# systemctl restart iscsid

- Log off all iSCSI session for safe.

		# iscsiadm -m node -u

- Discover iSCSI Target (argument of "-p" option should be set as FIP of iSCSI Target server)

		# iscsiadm -m discovery -t sendtargets -p 10.0.7.156

- Login to iSCSI Target which specified as -T argument.

		# iscsiadm -m node -T iqn.2016-10.test.target:t1 -p 10.0.7.156 -l

- Format/Initialise the iSCSI device and mount

		# mkfs -t ext4 <Data Partition Device Name>
		# mount /dev/disk/by-path/ip-192.168.137.134:3260-iscsi-iqn.2016-10.test.target:t1-lun-0-part2 /mnt/

		# dd if=/dev/zero of=<Cluster Partition Device Name>

		e.g.
		# dd if=/dev/zero of=/dev/disk/by-path/ip-192.168.137.134:3260-iscsi-iqn.2016-10.test.target:t1-lun-0-part1
