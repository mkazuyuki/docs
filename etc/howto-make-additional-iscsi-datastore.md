# Howto make additional iSCSI Datastore for HAUC

- [Preparing](#preparing)
- [Creating block device for iSCSI backstore](#creating-block-device-for-iscsi-backstore)
- [Configuring iSCSI Target](#configuring-iscsi-target)
- [Adding MD resource on iSCSI Cluster](#adding-md-resource-on-iscsi-cluster)
- [Adding Datastore on ESXi](#adding-datastore-on-esxi)

## Preparing

- Open Cluster WebManager for vMA Cluster ( http://172.31.255.6:29003/ )

  - Stop the clsuter for stopping the access to iSCSI Target from UC VMs.

## Creating block device for iSCSI backstore

- Open web browser and access to *vSphere Host Client*. ( http://172.31.255.2 , http://172.31.255.3 )

  - Add vHDD on both iSCSI VMs

- Open putty and login to iSCSI VMs.

  **on both iSCSI VM**
  - Make partitions oc the vH-D  - -est of-the-iscsi-ble space for data-partition.
  - Create the mount point for data-partition then format the data-partition. (assuming sdc2 as data-partition here and after)


	for iscsi01

		[root@iscsi01 ~]# mkfs.ext4 -O -64bit,-uninit_bg /dev/sdc2
		[root@iscsi01 ~]# mkdir /mirror2

	for iscsi02

		[root@iscsi02 ~]# mkfs.ext4 -O -64bit,-uninit_bg /dev/sdc2
		[root@iscsi02 ~]# mkdir /mirror2

## Configuring iSCSI Target

  **On primary iSCSI VM**,
  - Mount the data-partition.

		[root@iscsi01 ~]# mount /dev/sdc2 /mirror2

  - Confirm the available size of the data-partition.

		[root@iscsi01 ~]# df /dev/sdc2 --block-size=K
		Filesystem     1K-blocks     Used Available Use% Mounted on
		/dev/sdc2       9156948K   36888K  8631868K   1% /mirror2

	The available size is **8631868K** in this example.

  - Add the fileio backstore to the iSCSI Target

	Use the size of the data-partition as the option for **create** command.

		[root@iscsi01 ~]# targetcli
		/> cd /backstores/fileio
		/backstores/fileio> create idisk2 /mirror2/idisk2.img 8631868K sparse=false
		Writing 8839032832 bytes
		Created fileio idisk2 with size 8839032832
		/backstores/fileio> cd /iscsi/iqn.1996-10.com.ecx/tpg1/luns/
		/iscsi/iqn.19...ecx/tpg1/luns> create /backstores/fileio/idisk2
		Created LUN 1.
		Created LUN 1->1 mapping in node ACL iqn.1998-01.com.vmware:esxi67-2-46e2f217
		Created LUN 1->1 mapping in node ACL iqn.1998-01.com.vmware:esxi67-1-3c9771c3
		/iscsi/iqn.19...ecx/tpg1/luns> cd /
		/> saveconfig
		Last 10 configs saved in /etc/target/backup/.
		Configuration saved to /etc/target/saveconfig.json
		/> exit
		[root@iscsi01 ~]#

  - Copy the iSCSI Target configuration to another node.

		[root@iscsi01 ~]# scp /etc/target/saveconfig.json 172.31.254.12:/etc/target/
		root@172.31.254.12's password:
		saveconfig.json                                100% 7663     9.8MB/s   00:00
		[root@iscsi01 ~]#

  - Stop the failover group *failover-iscsi* to stop the access from the *target* service to the data-partition.

		[root@iscsi01 ~]# clpgrp -t

  - Unmount the data-partition.

		[root@iscsi01 ~]# umount /mirror2

## Adding MD resource on iSCSI Cluster.

- Open Cluster WebManager for iSCSI cluster ( http://172.31.255.11:29003/ )
- Change to [Config Mode] from [Operation Mode]
- Right click [failover-iscsi] in left pane > [Add Resource]
- Select [Type] as [mirror disk resource], set [Name] as [md2] then click [Next]
- [Next]
- [Next]
- Set
  - [ ext4 ] as [File System] 
  - [ /mirror2 ] as [Mount Point]
  - [ /dev/sdc2 ] as [Data Partition Device Name]
  - [ /dev/sdc1 ] as [Cluster Partition Device Name]
  - [Tuning] button > [Mirror] tab > uncheck [Execute initial mkfs] > [OK]
- [Finish]
- Click [Apply the Configuration File]
- Change to [Operation Mode] from [Config Mode]
- Start the *failover-iscsi*

## Adding datastore on ESXi
**On vSphere Host Client for both ESXi**
- Add the new datastore at [Storage] > [Adapters]
