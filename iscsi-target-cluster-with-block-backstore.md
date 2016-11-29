# Howto setup iSCSI Target Cluster on EXPRESSCLUSTER for Linux wtih block device back store 

----

This text descrives how to create iSCSI Target cluster (with block device back store) on EXPRESSCLUSTER for Linux.

----

## Revision histoory

2016.10.31 Miyamto Kazuyuki	1st issue

## Versions used
- RHEL7.2 x86_64
- ECX3.3.3-1

## Configuration

| Role of the node		 | Name    |
|--------------------------------|---------|
| Primary iSCSI Target Node	 | node-t1 |
| Secondary iSCSI Target Node	 | node-t2 |
| Primarry iSCSI Initiator Node  | node-i1 |
| Secondary iSCSI Initiator Node | node-i2 |

| Resource		   | Value			|
|--------------------------|----------------------------|
| FIP			   | 192.168.137.134		|
| Disk device for Target   | /dev/sdb			|
| WWN of iSCSI Target	   | iqn.2016-10.test.target:t1 |
| WWN of iSCSI Initiator 1 | iqn.2016-10.test.target:i1 |
| WWN of iSCSI Initiator 2 | iqn.2016-10.test.target:i2 |



## Procedure

On both servers,

- Install RHEL7, prepare block device for iSCSI Target Storage (e.g. /dev/sdb).

- Install packages

		# yum install targetcli targetd
		# rpm -ivh expresscls.*.rpm
		# clplcnsc -i [*base-license-file*] -p BASE33
		# clplcnsc -i [*replicator-license-file*] -p REPL33

----
On the client,

- Open EXPRESSCLUSTER Builder ( http://[IP of a host]:29003/ )
- Configure the cluster which have no failover-group with no group resource.

Add dummy failove-group to create NMP device. (NMP device is equal to mirror-disk device which will be provided as iSCSI Target device and will be accessed by iSCSI Initiator)
- [Cluster Properties] > [Interconnect] tab > set one of [MDC] as [mdc1]
- Right click [Groups] in left pane then click [Add Group]
- Set [Name] as *[failover-dummy]* then click [Next] (This failover group is configured just for preparing MD resource)
- Click [Next]
- Set [Startup Attribute] as [Manual Startup] then click [Next]
- Click [Add]
- Select [Type] as [mirror disk resource], set [Name] as [md1] then click [Next]
- Click [Next]
- Click [Next]
- Set

		[Mount Point] as [/mnt]
		[Data Partition Device Name] e.g. *[/dev/sdb2]*
		[Clsuter Partition Device Name] e.g. *[/dev/sdb1]*

- Click [Finish]

Add the failover-group for controlling NMP device and iSCSI Target service.
- Right click [Groups] in left pane then click [Add Group]
- Set [Name] as *[failover-iscsi]* then click [Next]
- Click [Next]
- Click [Next]
- Click [Add]
- Select [Type] as [execute resource] then click [Next]
- Click [Next]
- Click [Next]
- Select start.sh then click [Edit]. Add below lines.

		echo "Starting iSCSI Target"
		clpmdctrl -a -nomount md1
		systemctl start target
		echo "Started  iSCSI Target"

- Select stop.sh then click [Edit]. Add below lines.

		echo "Stopping iSCSI Target"
		systemctl stop target
		clpmdctrl -d md1
		echo "Stoped   iSCSI Target"

- Click [OK]
- Click [Add] and add  FIP resource.
- Click [Finish]
- Click [File] > [Apply Configuration]

*Note* : Do not start any failover-group here for following procedure.

----
On node-t1, prepare block device for iSCSI Target

- Initialize the mirror disk resource

		# clpmdctrl -f cent72-1 md1

- Wait for completion of mirror disk recovery ("recovery" means initialization in this situation)

		# clpmdstat -m md1

- Activate the mirror disk without mount.

		# clpmdctrl -a -nomount md1

On node-t1, Creating iSCSI Target

- Assuming the device name of the mirror disk resource as "/dev/NMP1" and the cluster partition as "/dev/sdb1". (the first mirror-disk resource of the cluster always named as "NMP1")

		# targetcli

- Create [ec-dp] as backstore

		/> backstores/block create ec-dp /dev/NMP1

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
