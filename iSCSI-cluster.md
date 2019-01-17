# Howto setup iSCSI Target Cluster on EXPRESSCLUSTER for Linux with fileio backstore

----

This text describes how to create iSCSI Target cluster (with fileio backstore) on EXPRESSCLUSTER for Linux.

----
## Versions used for the validation
- VMware vSphere Hypervisor 6.0 (VMware ESXi 6.0)
- Red Hat Enterprise Linux 7.2 x86_64
- EXPRESSCLUSTER X for Linux 3.3.3-1


## Network configuration example
![Netowrk configuraiton](HAUC-NW-Configuration.jpg)

## Nodes configuration example

iSCSI Target Cluster

|			| Primary		| Secondary		| FIP
|---			|---			|---			|---
| Hostname		| iscsi11		| iscsi2		|
| root password		|			|			|
|			|			|			|
| IP Address for iSCSI	| 192.168.0.11/24	| 192.168.0.12/24	| 192.168.0.10
| IP Address for mirror	| 192.168.1.11/24	| 192.168.1.12/24	|
| IP Address for manage	| 10.0.0.11/24  	| 10.0.0.12/24  	|


ESXi hosts

|				| Primary	| Secondary	|
|---				|---		|---		|
| Hostname			| esxi1		| esxi2		|
| root password			| passwd1	| passwd2	|
|				|		|		|
| IP Address for Management	| 10.0.0.1	| 10.0.0.2	|
|				|		|		|
| VMkernel for iSCSI Initiator	| 192.168.0.1	| 192.168.0.2	|
| WWN of iSCSI Initiator	| iqn.1998-01.com.vmware:1	| iqn.1998-01.com.vmware:2	|


| Role of the node		 | Host name | IP address			|
|--------------------------------|-----------|----------------------------------|
| Primary iSCSI Target Node	 | iscsi1    | 192.168.0.11/24, 192.168.1.11/24	|
| Secondary iSCSI Target Node	 | iscsi2    | 192.168.0.12/24, 192.168.1.12/24	|
| Primary ESXi			 | esxi1     | 192.168.0.1/24 , 10.0.0.1/24	|
| Secondary ESXi                 | esxi2     | 192.168.0.2/24 , 10.0.0.2/24	|
|                                |           |                                  |
| Primary iSCSI Initiator Node   | node-i1   | 192.168.0.21/24			|
| Secondary iSCSI Initiator Node | node-i2   | 192.168.0.22/24			|

## Parameters example

| Cluster Resources	   | Value			   |
|--------------------------|-------------------------------|
| FIP for iSCSI Target     | 192.168.0.10		   |
| Cluster Partition	   | /dev/sdb1			   |
| Data Partition	   | /dev/sdb2			   |
| WWN of iSCSI Target	   | iqn.1996-10.com.ecx:1 |
| WWN of iSCSI Initiator 1 | iqn.1998-01.com.vmware:1      |
| WWN of iSCSI Initiator 2 | iqn.1998-01.com.vmware:2      |

## Procedure

### Creating VMs on both ESXi

Configure each VM to have
- 3 vritual NICs
- 4 virtual CPUs
- 2 virtual HDDs, one for OS and another for MD resource which stores UC VMs.


### Installing OS and packages

On both iSCSI Target Nodes,

- Install RHEL7.2 and configure
	- hostname (e.g. iscsi1, iscsi2)
	- IP address (e.g. 10.0.0.11, 192.168.0.11, 192.168.1.11 for iscsi1)
	- block device for MD resoruce (e.g. /dev/sdb1 and /dev/sdb2).

- Install packages and EC licenses

		# yum install targetcli targetd
		# rpm -ivh expresscls.*.rpm
		# clplcnsc -i [base-license-file] -p BASE33
		# clplcnsc -i [replicator-license-file] -p REPL33

- Apply EC update (if you need)

- Reboot

		# reboot


### Configuring iSCSI Target Cluster

On the client PC,

- Open EXPRESSCLUSTER Builder ( http://192.168.0.11:29003/ )
- Configure the cluster *iSCSI-Cluster* which have no failover-group.
    - Configure two Heartbeat I/F


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
	- [Cluster Partition Device Name] as [ /dev/sdb1 ]
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


#### Add the first custom monitor resource for automatic MD recovery
- on Cluster Manager
  - change to [Operation Mode] from [Config Mode]
  - right click [Monitors] > [Add Monitor Resource]
  - [Info] section
    - select [custom monitor] as [type] > input *genw-md* > [Next]
  - [Monitor (common)] section
    - input *60* as [Wait Time to Start Monitoring]
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

#### Add the second custom monitor resource for updating arp table
- on Cluster Manager
  - change to [Operation Mode] from [Config Mode]
  - right click [Monitors] > [Add Monitor Resource]
  - [Info] section
    - select [custom monitor] as [type] > input *genw-arpw* > [Next]
  - [Monitor (common)] section
    - input *30* as [Interval]
    - select [Active] as [Monitor Timing]
    - [Browse] button
      - select [fip] > [OK]
    - [Next]
  - [Monitor (special)] section
    - [Replace]
      - select *genw-arpw.sh* > [Open] > [Yes]
    - input */opt/nec/clusterpro/log/genw-arpw.log* as [Log Output Paht] > check [Rotate Log]
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
      - write $VMNAME1 as VM name *iscsi1* in the esxi1 inventory
      - write $VMNAME2 as VM name *iscsi2* in the esxi2 inventory
      - write $VMIP1 as IP address for iscsi1
      - write $VMIP2 as IP address for iscsi2
      - write $VMK1 as IP address for esxi1 which accessible from iscsi1
      - write $VMK2 as IP address for esxi2 which accessible from iscsi2
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
- Reboot iscsi1, iscsi2 and wait for the completion of starting of the cluster *failover-iscsi*

### Configuring iSCSI Target
On iscsi1, create fileio backstore and configure it as backstore for the iSCSI Target.
- Login to the console of iscsi1.

- Start (iSCSI) target configuration tool

		# targetcli

- Unset automatic save of the configuration for safe.

		> set global auto_save_on_exit=false

- Create fileio backstore (*idisk*) which have required size on mountpoint of the mirror disk

		> cd /backstores/fileio
		> create idisk /mnt/idisk.img 2048M

- Creating IQN

		> cd /iscsi
		> create iqn.1996-10.com.ecx:1

- Assigning LUN to IQN

		> cd /iscsi/iqn.1996-10.com.ecx:1/tpg1/luns
		> create /backstores/fileio/idisk

- Allow machine (IQN of iSCSI Initiator) to scan the iSCSI target.

		> cd /iscsi/iqn.1996-10.com.ecx:1/tpg1/acls
		> create iqn.1998-01.com.vmware:1
		> create iqn.1998-01.com.vmware:2

- Save config and exit.

		> cd /
		> saveconfig
		> exit

- Copy the saved target configuration to the other node.

		# scp /etc/target/saveconfig.json iscsi2:/etc/target/

<!--
On iscsi2,

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
  - set WWN [iqn.1998-01.com.vmware:1] for the adapter
  - set IP address *192.168.0.10* for the iSCSI Target
- Select [Storage] > [Add Storage]
- Create [iSCSI] as datastore in the iSCSI Target

Do the same for esxi2. Use [*iqn.1998-01.com.vmware:2*] as WWN for its adapter.


### [Reference] Linux iSCSI Initiator configuration for general system

On node-i1

- Install tool for iSCSI Initiator.

		# yum install iscsi-initiator-utils

- Edit iSCSI Initiator configuration.

		# vi /etc/iscsi/initiatorname.iscsi

- Re-write "InitiatorName" and save it.

		InitiatorName=iqn.1998-01.com.vmware:1

- Restart iSCSI Initiator (restart iscsid due to rename of initiator)

		# systemctl restart iscsid

- Log off all iSCSI session for safe.

		# iscsiadm -m node -u

- Discover iSCSI Target ("-p" option should be set as FIP of iSCSI Target server)

		# iscsiadm -m discovery -t sendtargets -p 192.168.0.10

- Login to iSCSI Target which specified as -T argument.

		# iscsiadm -m node -T iqn.1996-10.com.ecx:1 -p 192.168.0.10 -l

- Format/Initialise the iSCSI device and mount

		# mkfs -t ext4 <iSCSI Device Name>
		# mount /dev/disk/by-path/ip-192.168.0.10:3260-iscsi-iqn.1996-10.com.ecx:1-lun-0-part1 /mnt/
<!--
		# dd if=/dev/zero of=<Cluster Partition Device Name>

		e.g.
		# dd if=/dev/zero of=/dev/disk/by-path/ip-192.168.137.134:3260-iscsi-iqn.1996-10.com.ecx:1-lun-0-part1
-->

## Revision history

2016.11.29 Miyamto Kazuyuki	1st issue
