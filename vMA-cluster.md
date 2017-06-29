# How to setup vMA Cluster on EXPRESSCLUSTER for Linux

----

This text descrives how to create vMA (vSphere Management Assisant) cluster on EXPRESSCLUSTER for Linux.

----
## Versions used for the validation
- VMware vSphere Hypervisor 6.0 (VMware ESXi 6.0)
- vSphere Management Assistant 6.0
- EXPRESSCLUSTER X for Linux 3.3.3-1

## Network configuration example
![Netowrk configuraiton](HAUC-NW-Configuration.jpg)

## Setup Procedure
- Prepare two nodes of ESXi (*esxi1* and *esxi2*) with shared-storage. The shared storage could be made of the iSCSI Target Cluster by ECX.
- Setup a VM (to be protected by ECX) on *esxi1* and name it *VM1* for example.
  The VM should be saved on the shared storage.

### Configuring Failover Group

- On ESXi-1 and ESXi-2
  - Deploy vMA OVF template on both ESXi and boot them.
  - Configure the netowrk for ESXi and vMA to make communicatable between vMA and VMkernel port.
    - ESXi Example:

		|		| Primary	| Secondary	|
		|---		|---		|---		|
		| Hostname	| esxi1		| esxi2		|
		| root password	| passwd1	| passwd2	|
		| Management IP	| 10.0.0.1	| 10.0.0.2	|

    - vMA Example:

		|		| Primary	| Secondary	| Note	|
		|---		|---		|---		|---	|
		| 3) Hostname	| vma1		| vma2		| need to be independent hostname ( "localhost" is inappropriate ) |
		| 6) IP Address	| 10.0.0.21	| 10.0.0.22	| need to be independent static IP Address |

    The IP address of vma1 and vma2 should be possible to communicate with VMkernel port of both ESXi and VM(s) to be monitored.

    - VM to be controlled:

		| Hostname	| IP address	|
		|---		|---		|
		| vm1   	| 10.0.0.101	|


- On vma1 and vma2 

  - Put ECX rpm file and its license file by using scp command and so on.
  - Install ECX

    	> sudo bash
    	# rpm -ivh expresscls-3.3.3-1.x86_64.rpm
    	# clplcnsc -I [license file] -P BASE33
    	# reboot

- Configure ECX On Cluster Manager
  - Access http://10.0.0.21:29003/ with web browser to open *Cluster Manager*
  - on Cluster Manager
    - change to [Config Mode] from [Operation Mode]
    - [File] > [Cluster Generation Wizard]
    - [Start Cluster Generation Wizard for standard edition]
    - Input *vMA-cluster* as Cluster Name, [English] as Language > [Next]
    - [Add] > input [IP Address of secondary server] > [OK] > [Next]
    - [Next]
    - [Next]
    - [Add]
    - input *failover-VMn* as [Name] > [Next]
    - [Next]
    - [Next]
    - [Add]
    - Select [execute resource] as [Type] > input *exec-VMn* as [Name] > [Next]
    - [Next]
    - Select [Stop the cluster service and regoot OS] as [Final Action] in [Recovery Operation at Deactivation Failure Detection] > [Next]
    - Select [start.sh] > [Replace] > Select *vm-start.pl* >
    - [Edit] > followings need to be specified in the script.
        - the path to the VM configuration file (.vmx) as *@cfg_paths*.  
          it can be obtaind at vMA console as below.

    			$ sudo bash
    			# vmware-cmd --server 10.0.0.1 -U root -l 
    		
    			/vmfs/volumes/588b1739-87411a6f-618f-002421a9b4be/vm1/vm1.vmx

        - Datastore name as *$datastore* which the VM to be protected is stored.
        - IP addresses for VMkernel Port for both ESXi as *$vmk1* and *$vmk2* which is accessible from the vMA Cluster nodes.
        - IP addresses for the Cluster nodes as *$vma1* and *$vma2* which is used for accessing to VMkernel Port.
    - Select [stop.sh]  > [Replace] > Select *vm-stop.pl* >
    - [Edit] > the same with *start.sh* need to be specified.
    - [Tuning] > [Maintenance] tab > Input */opt/nec/clusterpro/log/exec-VMn.log* as [Log Outpu Path] > Check [Rotate Log] > [OK] > [Finish]
    - [Finish]
    - [Next]
    - [Add] > select [custom monitor] as [Type] > input *genw-VMn* as [Name] > [Next]
    - select [Active] as [Monitoring Timig] > [Browse] >  
      select [exec-VMn] > [OK] > [Next]
    - [Replace] > select *genw-vm.pl* >
    - [Edit] > Parameters in the belows need to be specified in the script.  
      (these parameters are the same as start.sh and stop.sh of exec-VMn)
        - The path to the VM configuration file (.vmx) as *@cfg_paths*.  
        - IP addresses for VMkernel Port for both ESXi as *$vmk1* and *$vmk2* which is accessible from the vMA Cluster nodes.
        - IP addresses for the Cluster nodes as *$vma1* and *$vma2* which is used for accessing to VMkernel Port.
    - input */opt/nec/clusterpro/log/genw-VMn.log* as [Log Output Path] >  
      Check [Rotate Log] > [Next]
    - select [Executing failover to the recovery target] > [Browse] >  
      select [failvoer-VMn] > [OK] >  
      [Finish]
    - [Finish] > [Yes]
    - [File] menu > [Apply the Configuration File]
    - **OPTIONAL** : Do the followings if iSCSI Target Cluster and vMA Cluster need to be failed over simultaneously.
        ----
        - Right click [failover-VMn] in left pane > [Add Resource]
        - Select [Type] as [execute resource] > Input [*exec-VMn-datastore*] as [Name] > [Next]
        - [Next]
        - [Next]
        - Select [start.sh] > [Replace] > Select [*exec-vm-datastore.sh*]
        - [Edit] > followings need to be specified in the start.sh.
             - the name of the failover group in iSCSI Target Cluster (e.g. failover-iscsi) as *GRP*.

             		GRP="failover-iscsi"
             
             - IP address for primary node of iSCSI Target Cluster as *IP1*,
	       and for secondary node as *IP2*. These IP addresses should be accessible from vMA Cluster nodes.
             
             		IP1="10.0.0.11"
             		IP2="10.0.0.12"
             
        - [Tuning] > [Maintenance] tab > Input [*/opt/nec/clusterpro/log/exec-VMn-datastore.log*] as [Log Outpu Path] > Check [Rotate Log] > [OK]
        - [Finish]
        - Right click [exec-VMn] in right pane > [Properties]
        - [Dependency] tab > Uncheck [Follow the default dependency] > Click [Add] for exec-datastore > [OK]
        - [File] menu > [Apply the Configuration File]
        ----

  - on the console of both node (vma1, vma2)  
    Register root password of both ESXi to enable vmware-cmd and esxcli command accessing ESXi without password.

    	> sudo bash
    	# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s 10.0.0.1 -u root -p passwd1
    		New entry added successfully
    	# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s 10.0.0.2 -u root -p passwd2
    	New entry added successfully
    	# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl list
    		Server	user Name
    		10.0.0.1	root
    		10.0.0.2	root
    		
    		Server 	Thumbprint
    	# exit
    	>
    
  - on vma1 console
    setup ESXi thumbprint to use esxcli command

    	$ sudo bash
    	# esxcli -s 10.0.0.1 -u root vm process list
    	Connect to 10.0.0.1 failed. Server SHA-1 thumbprint: AD:5C:1E:DF:E6:39:18:B8:F9:65:EE:09:5A:7C:B4:E6:90:45:DB:DC (not trusted).
    	# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s 10.0.0.1 -t AD:5C:1E:DF:E6:39:18:B8:F9:65:EE:09:5A:7C:B4:E6:90:45:DB:DC
    	New entry added successfully

  - on vma2 console
    setup ESXi thumbprint to use esxcli command

    	$ sudo bash
    	# esxcli -s 10.0.0.2 -u root vm process list
    	Connect to 10.0.0.2 failed. Server SHA-1 thumbprint: AD:5C:1E:DF:E6:39:18:B8:F9:65:EE:09:5A:7C:B4:E6:90:45:DB:DC (not trusted).
    	# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s 10.0.0.2 -t AD:5C:1E:DF:E6:39:18:B8:F9:65:EE:09:5A:7C:B4:E6:90:45:DB:DC
    	New entry added successfully

<!--
  - on vma1
    - Get the path information for the VMn with the command.  
      This information will be used when editing *vmconf.pl*.

    		$ sudo bash
    		# vmware-cmd --server 10.0.0.1 -U root -l 
    		
    		/vmfs/volumes/588b1739-87411a6f-618f-002421a9b4be/cent7/cent7.vmx

    - copy *vmconf.pl* to /opt/nec/clusterpro/scripts/failover-VMn/exec-VMn/vmconf.pl
    - edit *vmconf.pl* accordingly
    - copy *vmconf.pl* to /opt/nec/clusterpro/scripts/monitor.s/genw/vmconf.pl
    - distribute the configuration (vmconf.pl) to vma2

    		# clpcfctrl --push
-->

  - on Cluster Manager

    - change to [Operation Mode] from [Config Mode]
    - [Service] menu > [Start Cluster]

### Configuring Monitor resource
- On both vSphere Client for esxi1 and esxi2
  - click ESXi host icon in left pane.
  - Select [Configuration] tab > [Security Profile] > [Properties] of Services
  - Check [Start and stop with host] > push [Start] button and make "ssh" running.
  
- On vma1 console
  - copy public key of root user to esxi2

    	> sudo bash
    	# scp ~/.ssh/id_rsa.pub 10.0.0.2:/etc/ssh/keys-root/

  - remote login to esxi2 as root user and configure ssh for remote execution from vma1.

    	# ssh 10.0.0.2
	Password:

    	# cd /etc/ssh/keys-root
    	# cat id_rsa.pub >> authorized_keys
    	# exit

    	# exit
    	> exit

- On vma2 console (do the same for esxi1 (10.0.0.1))
  - copy public key of root user to esxi1
  - remote login to esxi1 as root user and configure ssh for remote execution from vma2.

<!--
- on vma1
  - edit */opt/nec/clusterpro/scripts/monitor.s/genw-esxi-inventory/vmconf.pl*

    	> sudo bash
    	# mkdir /opt/nec/clusterpro/scripts/monitor.s/genw-esxi-inventory
     	# vi    /opt/nec/clusterpro/scripts/monitor.s/genw-esxi-inventory/vmconf.pl
    	# cat   /opt/nec/clusterpro/scripts/monitor.s/genw-esxi-inventory/vmconf.pl
    	#--------
    	# The path to datastore which VM configuration file stored.
    	#       This value is used to delete VMs from inventory of standby node
    	our $DatastorePath = "/vmfs/volumes/58a7297f-5d0c41f3-b7a5-000c2964975f";
    
    	# IP addresses for VM kernel port.
    	our $vmk1 = "10.0.0.1";
    	our $vmk2 = "10.0.0.2";
    	1;
    	#--------
-->
#### Adding monitor for remote ESXi iSCSI session and ESXi inventory
- on Cluster Manager
  - change to [Operation Mode] from [Config Mode]
  - right click [Monitors] > [Add Monitor Resource]
  - [Info] section
    - select [custom monitor] as [type] > input *genw-remote-esxi* > [Next]
  - [Monitor (common)] section
    - input *180* as [Interval]
    - input *60* as [Wait Time ot Start Monitoring]
    - select [Active] as [Monitor Timing]
    - [Browse] button
      - [exec-VMn] > [OK]
    - [Server]
      - select [Select] > [Add] (adding vma1) > [OK]
    - [Next]
  - [Monitor (special)] section
    - [Replace]
      - select *genw-remote-esxi.pl* > [Open] > [Yes]
    - [Edit]
      - write $DatastoreName as iSCSI datastore
      - write $vmk1 as IP address for esxi1
      - write $vmk2 as IP address for esxi2
      - write $vma1 as IP address for vma1
      - write $vma2 as IP address for vma2
      - write $vmhba1 as the name of iSCSI Software Adapter on esxi1
      - write $vmhba2 as the name of iSCSI Software Adapter on esxi2
    - input */opt/nec/clusterpro/log/genw-esxi.log* as [Log Output Paht] > check [Rotate Log]
    - [Next]
  - [Recovery Action] section
    - select [Execute only the final action] as [Recovery Action]
    - [Browse]
      - [LocalServer] > [OK]
    - select [No operation] as [Final Action]
    - [Finish]

#### Adding Network Monitor for VMn
- on Cluster Manager
  - right click [Monitors] > [Add Monitor Resource]
  - [Info] section
    - select [ip monitor] as [type] > input *ipw-VMn* > [Next]
  - [Monitor (common)] section
    - input *600* as [Wait Time ot Start Monitoring]
    - select [Active] as [Monitor Timing]
    - [Browse] button
      - [exec-VMn] > [OK]
    - [Next]
  - [Monitor (special)] section
    - [Add]
      - input IP address of VMn (e.g. 10.0.0.100)  
        **[ Note ]**  Adding NIC on vma1 and vma2 is required if the VMn belongs to the defferent network than vma1 and vma2.
	Configure the IP address for the additional NIC to have the same network address with VMn.  
		/etc/sysconfig/networking/devices/ifcfg-eth1  
	and symbolic link file  
		/etc/sysconfig/network/ifcfg-eth1  
	should be configured. 
      - [OK]
    - [Next]
  - [Recovery Action] section
    - select [Executing failover to the recovery target] as [Recovery Action]
    - [Browse]
      - select [failover-VMn] > [OK]
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
      - write $VMNAME1 as VM name of vma1 in the esx01 inventory
      - write $VMNAME2 as VM name of vma2 in the esx02 inventory
      - write $VMIP1 as IP address for vma1
      - write $VMIP2 as IP address for vma2
      - write $VMK1 as IP address for esxi1
      - write $VMK2 as IP address for esxi2
    - input */opt/nec/clusterpro/log/genw-remote-node.log* as [Log Output Paht] > check [Rotate Log]
    - [Next]
  - [Recovery Action] section
    - select [Execute only the final action] as [Recovery Action]
    - [Browse]
      - [LocalServer] > [OK]
    - select [No operation] as [Final Action]
    - [Finish]

### Applying the configuration
    - [File] menu > [Apply the Configuration File]

--------

## Tips

### How to know the existence of (iSCSI) datastore by esxcli command

https://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.vcli.examples.doc_50/cli_advanced_storage.8.2.html?path=1_1_0_5_0_0#463363

## Notes

- On the tree view in left pane of vSphere Client, delete the object (manually)if VMs to be protected is displayed with gray color as

	/vmfs/volumes/[LUNID]/[vm name]/[vm name].vmx (inaccessible)

  Right click the object > [Remove from Inventory]

  If it remains, the VM registration operation by the failover group will be failed.


- Linux guest VM which **open-vm-tools** package is installed cannot be monitord by the custom monitor resource (genw-VMn).
The VM is treated as if vmware-tools is not installed and always normal as the result of the monitoring.

<!--
## TBD
- Integrate genw-remote-esxi.pl and genw-remote-node.pl into one.
- Eliminating dependency on VMware API (vmware-cmd and esxcli) with ssh + vim-* command
-->

## Revision history
2017.02.03	Miyamto Kazuyuki	1st issue
