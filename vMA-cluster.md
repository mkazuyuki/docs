# How to setup vMA cluster

----

This text descrives how to create vMA (vSphere Management Assisant) cluster on EXPRESSCLUSTER for Linux.

----
## Revision histoory
2017.02.03	Miyamto Kazuyuki	1st issue

## Versions used
- VMware vSphere Hypervisor 6.0 (VMware ESXi 6.0)
- EXPRESSCLUSTER X for Linux 3.3.3-1

## Setup Procedure
- Preare two nodes of ESXi (*esxi01* and *esxi02*) with shared-storage.
- Setup a VM (to be protected by ECX) on *esxi01* and name it *VM1* for example.

### Configuring Failover Group

- On ESXi-1 and ESXi-2
  - Deploy vMA OVF template on both ESXi and boot them.
  - Configure the netowrk for ESXi and vMA to make communicatable between vMA and VMkernel port.

	ESXi Example:

	|			| Primary	| Secondary	|
	|---			|---		|---		|
	| Hostname		| esxi01	| esxi02	|
	| VMkernel IP Address	| 10.0.0.1	| 10.0.0.2	|
	| root password		| passwd1	| passwd2	|

	vMA Example:

	|			| Primary	| Secondary	| Note	|
	|---			|---		|---		|---	|
	| 3) Hostname		| vma01		| vma02		| need to have independent hostname ( "localhost" is inappropriate ) |
	| 4) DNS		|		|		||
	| 5) Proxy Server	|		|		||
	| 6) IP Address		| 10.0.0.11	| 10.0.0.12	| need to have independent static IP Address |

  the IP address should be possible to communicate with VMkernel of both ESXi.

- On vMA-1 and vMA-2 

  - Put ECX rpm file and its license file by using scp command and so on.
  - Install ECX

    		> sudo bash
    		# rpm -ivh expresscls-3.3.3-1.x86_64.rpm
    		# clplcnsc -I [license file] -P BASE33
    		# reboot

- Configure ECX On Cluster Manager
  - Access http://[IP_Address_of_Primary_node]:29003/ with web browser to open *Cluster Manager*
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
      Select [stop.sh]  > [Replace] > Select *vm-stop.pl* >  
      [Tuning] > [Maintenance] tab > Input */opt/nec/clusterpro/log/exec-VMn.log* as [Log Outpu Path] > Check [Rotate Log] > [OK] > [Finish]
    - [Finish]
    - [Next]
    - [Add] > select [custom monitor] as [Type] > input *genw-VMn* as [Name] > [Next]
    - select [Active] as [Monitoring Timig] > [Browse] >  
      select [exec-VMn] > [OK] > [Next]
    - [Replace] > select *vm-monitor.pl* >  
      input */opt/nec/clusterpro/log/genw-VMn.log* as [Log Output Path] >  
      Check [Rotate Log] > [Next]
    - select [Executing failover to the recovery target] > [Browse] >  
      select [failvoer-VMn] > [OK] >  
      [Finish]
    - [Finish] > [Yes]
    - [File] menu > [Apply the Configuration File]

  - on both node (vma01, vma02)
    - setup root user credential for both ESXi by using /usr/lib/vmware-vcli/apps/general/credstore_admin.pl

    		> sudo /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s {IP_of_esxi01} -u root -p {password}
    		> sudo /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s {IP_of_esxi02} -u root -p {password}

  - on vma01, setup ESXi thumbprint to use esxcli command

    		$ sudo bash
    		# esxcli -s 10.0.0.1 -u root vm process list
    		Connect to 10.0.0.1 failed. Server SHA-1 thumbprint: AD:5C:1E:DF:E6:39:18:B8:F9:65:EE:09:5A:7C:B4:E6:90:45:DB:DC (not trusted).
    		# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s 10.0.0.1 -t AD:5C:1E:DF:E6:39:18:B8:F9:65:EE:09:5A:7C:B4:E6:90:45:DB:DC
    		New entry added successfully

  - on vma02, setup ESXi thumbprint to use esxcli command

    		$ sudo bash
    		# esxcli -s 10.0.0.2 -u root vm process list
    		Connect to 10.0.0.2 failed. Server SHA-1 thumbprint: AD:5C:1E:DF:E6:39:18:B8:F9:65:EE:09:5A:7C:B4:E6:90:45:DB:DC (not trusted).
    		# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s 10.0.0.2 -t AD:5C:1E:DF:E6:39:18:B8:F9:65:EE:09:5A:7C:B4:E6:90:45:DB:DC
    		New entry added successfully

  - on vma01

    - Get the path information for the VMn with the command.  
      This information will be used when editing vmcon.pl.

    		# sudo vmware-cmd --server 10.0.0.1 -U root -l 
    		
    		/vmfs/volumes/588b1739-87411a6f-618f-002421a9b4be/cent7/cent7.vmx

    - copy *vmconf.pl* to /opt/nec/clusterpro/scripts/failover-VMn/exec-VMn/vmconf.pl
    - edit *vmconf.pl* accordingly
    - copy *vmconf.pl* to /opt/nec/clusterpro/scripts/monitor.s/genw/vmconf.pl
    - distribute the configuration (vmconf.pl) to vma02

    		# clpcfctrl --push

  - on Cluster Manager

    - change to [Operation Mode] from [Config Mode]
    - [Service] menu > [Start Cluster]

### Configuring Monitor resource
- On both vSphere Client for esxi01 and esxi02
  - click ESXi host icon in left pane.
  - Select [Configuration] tab > [Security Profile] > [Properties] of Services
  - Make "ssh" running.
  
- On vma01
  - copy public key of root user to esxi02

    	> sudo bash
    	# scp ~/.ssh/id_rsa.pub 10.0.0.2:/etc/ssh/keys-root/

  - remote login to esxi02 as root user and configure ssh for remote login.

    	# ssh 10.0.0.2
	Password:

    	# cd /etc/ssh/keys-root
    	# cat id_rsa.pub >> authorized_keys
    	# exit

    	# exit
    	> exit

- On vma02 (do the same for esxi01 (10.0.0.1))
  - copy public key of root user to esxi01
  - remote login to esxi01 as root user and configure ssh for remote login.

- on vma01
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

- on Cluster Manager
  - change to [Operation Mode] from [Config Mode]
  - right click [Monitors] > [Add Monitor Resource]
  - Info
    - select [custom monitor] asn [type] > input *genw-esxi-inventory* > [Next]
  - Monitor (common)
    - input *60* as [Wait Time ot Start Monitoring]
    - select [Active] as [Monitor Timing]
    - [Browse] button
      - [exec-VMn] > [OK]
    - [Server]
      - select [Select] > [Add] (adding vma01) > [OK]
    - [Next]
  - Monitor (special)
    - [Replace]
      - select *genw-esxi-inventory.sh* > [Open] > [Yes]
    - input */opt/nec/clusterpro/log/genw-esxi-inventory.log* as [Log Output Paht] > check [Rotate Log] 
    - [Next]
  - Recovery Action
    - select [Execute only the final action] as [Recovery Action]
    - [Browse]
      - [LocalServer] > [OK]
    - select [No operation] as [Final Action]
    - [Finish]

- on vma01
  - reflect vmconf.pl from vma01 to vma02

    		# clpcfctrl --push

## Tips

### Registering ESXi root credential on vMA HOWTO 

Assuming belows.

- IP address for "VMkernel port" of ESXi host
	- 10.0.0.1	(for ESXi-1)
	- 10.0.0.2	(for ESXi-2)

- IP address for "vSphere Management Assistant" on ESXi
	- 10.0.0.11	(for vMA-1 on ESX-1)
	- 10.0.0.12	(for vMA-2 on ESX-2)

- root password to access "VMkernel port" is
	- passwd1	(for 10.0.0.1)
	- passwd2	(for 10.0.0.2)

On vMA-1 console, register root password to allow access from EC scrips as below.

	# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s 10.0.0.1 -u root -p passwd1
	New entry added successfully
	# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s 10.0.0.2 -u root -p passwd2
	New entry added successfully
	# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl list
	Server	user Name
	10.0.0.1	root
	10.0.0.2	root
		
	Server 	Thumbprint
	#

### open-vm-tools on Linux VM

Lnux guest VM which **open-vm-tools** is installed cannot be monitord by the custom monitor resource (genw-VMn).
The VM is treated as if vmware-tools is not installed and always normal.

<!--
### (iSCSI) storage の存在を確認する方法

https://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.vcli.examples.doc_50/cli_advanced_storage.8.2.html?path=1_1_0_5_0_0#463363


# vMA の OVF を他の環境でデプロイして使う場合に変更が必要となる部分

	- 保護対象の VM を共有ディスク (iSCSI Target) に移動させる。
		- vSphere Client から Datastore Browser を使って .vmx の入っているフォルダを まるごと共有ディスクへコピーする
		- 「

	- /opt/nec/clusterpro/scripts/{Group Name}/{Resource Name}/vmconf.pl
		- 保護対象 VM の vmkernel 内での格納 path

			vMA にログインして以下のコマンドで出力される .vmx ファイルのパスを指定する。
			
				# vmware-cmd -H {ESXi#1_IP} -U root -P {password} -l
	 	
	 	- ESXi 1号機、2号機の VMkernel port の IP address
	 	- vMA 1号機、2号機の IP address

	- /usr/lib/vmware-vcli/apps/general/credstore_admin.pl
	 を使って ESXi 1, 2号機の root パスワード を vMA に登録する。
	
	 	/usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s {ESXi#1_IP} -u root -p {password}


- On vMA-1 console, register root password to allow access from EC scrips as below.

		> sudo bash
		# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s 10.0.0.1 -u root -p passwd1
		New entry added successfully
		# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s 10.0.0.2 -u root -p passwd2
		New entry added successfully
		# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl list
		Server       User Name
		10.0.0.1     root
		10.0.0.2     root

		Server       Thumbprint
		#


## Notes

管理対象VM が vSphere Clinet 上、左ペインのツリーに、

	/vmfs/volumes/[LUNID]/[vm name]/[vm name].vmx (inaccessible)

と 薄いグレー で表示されている場合は、それらを **手動で** 削除する

	対象VMを右クリック > [Remove from Inventory]


-->
