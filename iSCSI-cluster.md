# Howto setup iSCSI Target Cluster on EXPRESSCLUSTER for Linux with fileio backstore 

----

This text descrives how to create iSCSI Target cluster (with fileio backstore) on EXPRESSCLUSTER for Linux.

----

## Revision histoory

2016.11.29 Miyamto Kazuyuki	1st issue

## Versions used
- RHEL7.2 x86_64
- ECX3.3.3-1

## Nodes configuration example

iSCSI Target nodes

|			| Primary		| Secondary		| FIP
|---			|---			|---			|---
| Hostname		| node-t1		| node-t2		|
| IP Address for iSCSI	| 192.168.0.11/24	| 192.168.0.12/24	| 192.168.0.10
| IP Address for mirror	| 192.168.1.11/24	| 192.168.1.12/24	| 
| root password		| passwd1		| passwd2		|


ESXi hosts

|			| Primary	| Secondary	|
|---			|---		|---		|
| Hostname		| esxi01	| esxi02	|
| VMkernel for iSCSI	| 192.168.0.1	| 192.168.0.2	|
| iSCSI Initiator WWN	| 
| Management		| 10.0.0.1	| 10.0.0.2	|
| root password		| passwd1	| passwd2	|


| Role of the node		 | Host name | IP address			|
|--------------------------------|-----------|----------------------------------|
| Primary iSCSI Target Node	 | node-t1   | 192.168.0.11/24, 192.168.1.11/24	|
| Secondary iSCSI Target Node	 | node-t2   | 192.168.0.12/24, 192.168.1.12/24	|
| Primarry ESXi			 | esxi1     | 192.168.0.1/24 , 10.0.0.1/24	|
| Secondary ESXi                 | esxi2     | 192.168.0.2/24 , 10.0.0.2/24	|
| Primarry iSCSI Initiator Node  | node-i1   | 192.168.0.21/24			|
| Secondary iSCSI Initiator Node | node-i2   | 192.168.0.22/24			|

## Parameters example

| Cluster Resources	   | Value			   |
|--------------------------|-------------------------------|
| FIP			   | 192.168.0.10		   |
| Cluster Partition	   | /dev/sdb1			   |
| Data Partition	   | /dev/sdb2			   |
| WWN of iSCSI Target	   | iqn.2016-10.test.target:t1    |
| WWN of iSCSI Initiator 1 | iqn.2016-10.test.initiator:i1 |
| WWN of iSCSI Initiator 2 | iqn.2016-10.test.initiator:i2 |

## Procedure

### Installing OS and packages

On both iSCSI Target Nodes,

- Install RHEL7 and configure
	- hostname (e.g. node-t1, node-t2)
	- IP address (e.g. 192.168.0.11 for node-t1, 192.168.0.12 for node-t2)
	- block device for MD resoruce (e.g. /dev/sdb1 and /dev/sdb2).

- Install packages and EC licenses

		# yum install targetcli targetd
		# rpm -ivh expresscls.*.rpm
		# clplcnsc -i [base-license-file] -p BASE33
		# clplcnsc -i [replicator-license-file] -p REPL33

### Configuring iSCSI Target Cluster

On the client PC,

- Open EXPRESSCLUSTER Builder ( http://192.168.0.11:29003/ )
- Configure the cluster *iSCSI-Cluster* which have no failover-group.
    - Confgure two Heartbeat I/F 


#### Add the failover-group for controlling iSCSI Target service.
- Right click [Groups] in left pane > [Add Group]
- Set [Name] as [*failover-iscsi*]  > [Next]
- [Next]
- [Next]
- [Finish]

#### Add the MD resource
- Right click [iSCSI-Cluster] in left pane > [Properties]
- [Interconnect] tab > set [mdc1] for [MDC] and 10.0.0.0/24 network > [OK]
- Right click [failover-iscsi] in left pane > [Add Resource]
- Select [Type] as [mirror disk resource], set [Name] as [md1] then click [Next]
- [Next]
- [Next]
- Set
	- [Mount Point] as [/mnt]
	- [Data Partition Device Name] as [ /dev/sdb2 ]
	- [Clsuter Partition Device Name] as [ /dev/sdb1 ]
- [Finish]

#### Add the execute resource for controlling target service
- Right click [failover-iscsi] in left pane > [Add Resource]
- Select [Type] as [execute resource] then click [Next]
- [Next]
- [Next]
- Select start.sh then click [Edit]. Add below lines.

		echo "Starting iSCSI Target"
		systemctl start target
		echo "Started  iSCSI Target"

- Select stop.sh then click [Edit]. Add below lines.

		echo "Stopping iSCSI Target"
		systemctl stop target
		echo "Stopped   iSCSI Target"

- [Finish]

#### Add floating IP resource for iSCSI Target
- Right click [failover-iscsi] in left pane > [Add Resource]
- Select [Type] as [floating IP resource] then click [Next]
- [Next]
- [Next]
- Set floating IP address as [ 192.168.0.10 ] 
- Click [Finish]

#### Add the execute resource for automatic MD recovery
This resource is used for the **special case**

- Right click [failover-iscsi] in left pane > [Add Resource]
- Select [Type] as [execute resource], set [Name] as [*exec-md-recovery*] then click [Next]
- Uncheck [Follow the default dependency] > [Next]
- [Next]
- Select start.sh then click [Replace]
- Select [*exec-md-recovery.pl*]
- [Finish]


#### Add the custom monitor resource for automatic MD recovery
- on Cluster Manager
  - change to [Operation Mode] from [Config Mode]
  - right click [Monitors] > [Add Monitor Resource]
  - [Info] section
    - select [custom monitor] as [type] > input *genw-md* > [Next]
  - [Monitor (common)] section
    - input *60* as [Wait Time ot Start Monitoring]
    - select [Active] as [Monitor Timing]
    - [Browse] button
      - select [md1] > [OK]
    - [Next]
  - [Monitor (special)] section
    - [Replace]
      - select *genw-md.pl* > [Open] > [Yes]
    - input */opt/nec/clusterpro/log/genw-md.log* as [Log Output Paht] > check [Rotate Log]
    - [Next]
  - [Recovery Action] section
    - select [Execute only the final action] as [Recovery Action]
    - [Browse]
      - [LocalServer] > [OK]
    - select [No operation] as [Final Action]
    - [Finish]

#### Adding Monitor which make remote vMA VM and ECX keep online.
- on Cluster Manager
  - change to [Operation Mode] from [Config Mode]
  - right click [Monitors] > [Add Monitor Resource]
  - [Info] section
    - select [custom monitor] as [type] > input *genw-remote-node* > [Next]
  - [Monitor (common)] section
    - select [Always] as [Monitor Timing]
    - [Next]
  - [Monitor (special)] section
    - [Replace]
      - select *genw-remote-node.pl* > [Open] > [Yes]
    - [Edit]
      - write $VMNAME1 as VM name of node-t1 in the esx01 inventory
      - write $VMNAME2 as VM name of node-t2 in the esx02 inventory
      - write $VMIP1 as IP address for node-t1
      - write $VMIP2 as IP address for node-t2
      - write $VMK1 as IP address for esxi01
      - write $VMK2 as IP address for esxi02
    - input */opt/nec/clusterpro/log/genw-remote-node.log* as [Log Output Paht] > check [Rotate Log]
    - [Next]
  - [Recovery Action] section
    - select [Execute only the final action] as [Recovery Action]
    - [Browse]
      - [LocalServer] > [OK]
    - select [No operation] as [Final Action]
    - [Finish]

#### Apply the configuration
- Click [File] > [Apply Configuration]
- Reboot node-t1, node-t2 and wait for the completion of starting of the cluster *failover-iscsi*

### Configuring iSCSI Target
On node-t1, create fileio backstore and configure it as backstore for the iSCSI Target.
- Login to the console of node-t1.

- Start (iSCSI) target configuration tool

		# targetcli

- Unset automatic save of the configuration for safe.

		> set global auto_save_on_exit=false

- Create fileio backstore (*idisk*) which have required size on mountpoint of the mirror disk

		> cd /backstores/fileio
		> create idisk /mnt/idisk.img 2048M

- Creating IQN

		> cd /iscsi
		> create iqn.2016-10.test.target:t1

- Assigning LUN to IQN

		> cd /iscsi/iqn.2016-10.test.target:t1/tpg1/luns
		> create /backstores/fileio/idisk

- Allow machine (IQN of iSCSI Initiator) to scan the iSCSI target.

		> cd /iscsi/iqn.2016-10.test.target:t1/tpg1/acls
		> create iqn.2016-10.test.initiator:i1
		> create iqn.2016-10.test.initiator:i2

- Save config and exit.

		> saveconfig
		> exit

- Copy the saved target configuration to the other node.

		# scp /etc/target/saveconfig.json node-t2:/etc/target/

<!--
On node-t2,

- Activate the mirror disk

		# clpmdctrl -a -nomount md1

- Restore iSCSI Target configuration

		# targetcli restoreconfig
-->

### SCSI Initiator configuration for ESXi
- Open [vSphere Client] and connect to esxi1
- Click ESXi host icon at the top of left pane.
- Select [Configuration] tab in right pane.
- Select [Storage Adapter] > [Add]
- Configure [iSCSI Software Adapter]
  - set WWN [iqn.2016-10.test.initiator:i1] for the adapter
  - set IP address *192.168.0.10* for the iSCSI Target
- Select [Storage] > [Add Storage]
- Create [iSCSI] as datastore in the iSCSI Target

Do the same for esxi2.


### [Reference] Linux iSCSI Initiator configuration for general system

On node-i1

- Edit iSCSI Initiator configuration.

		# vi /etc/iscsi/initiatorname.iscsi

- Re-write "InitiatorName" and save it.

		InitiatorName=iqn.2016-10.test.initiator:i1

- Restart iSCSI Initiator (restart iscsid due to rename of initiator)

		# systemctl restart iscsid

- Log off all iSCSI session for safe.

		# iscsiadm -m node -u

- Discover iSCSI Target ("-p" option should be set as FIP of iSCSI Target server)

		# iscsiadm -m discovery -t sendtargets -p 192.168.0.10

- Login to iSCSI Target which specified as -T argument.

		# iscsiadm -m node -T iqn.2016-10.test.target:t1 -p 192.168.0.10 -l

- Format/Initialise the iSCSI device and mount

		# mkfs -t ext4 <iSCSI Device Name>
		# mount /dev/disk/by-path/ip-192.168.0.10:3260-iscsi-iqn.2016-10.test.target:t1-lun-0-part1 /mnt/
<!--
		# dd if=/dev/zero of=<Cluster Partition Device Name>

		e.g.
		# dd if=/dev/zero of=/dev/disk/by-path/ip-192.168.137.134:3260-iscsi-iqn.2016-10.test.target:t1-lun-0-part1
-->