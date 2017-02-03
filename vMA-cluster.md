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

#### On ESXi-1 and ESXi-2
- Deploy vMA OVF template on both ESXi and boot them.
- Configure the netowrk for ESXi and vMA to make communicatable between vMA and VMkernel port.

ESXi Example:

|			| Primary	| Secondary	|
|--			|--		|--		|
| Hostname		| esxi01	| esxi02	|
| VMkernel IP Address	| 10.0.0.1	| 10.0.0.2	|

vMA Example:

|			| Primary	| Secondary	| Note	|
|--			|--		|--		|--	|
| 3) Hostname		| vma01		| vma02		| should have independent hostname ( "localhost" is inappropriate ) |
| 4) DNS		|		|		||
| 5) Proxy Server	|		|		||
| 6) IP Address		| 10.0.0.11	| 10.0.0.12	| should have independent static IP Address |

  the IP address should be possible to communicate with VMkernel of both ESXi.

#### On vMA-1 and vMA-2 
- Put ECX rpm file and its license file by using scp command and so on.
- Install ECX

		> sudo bash
		# rpm -ivh expresscls-3.3.3-1.x86_64.rpm
		# clplcnsc -I [license file] -P BASE33
		# reboot

- Configure ECX
  - Access http://[IP_Address_of_Primary_node]:29003/ with web browser to open *Cluster Manager*
  - Change to [Config Mode] from [Operation Mode]
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
  - Select [start.sh] > [Replace] > Select *vm-start.pl*  
    Select [stop.sh]  > [Replace] > Select *vm-stop.pl*  
    [Tuning] > [Maintenance] tab > Input */opt/nec/clusterpro/log/exec-VMn.log* as [Log Outpu Path] > Check [Rotate Log] > [OK] > [Finish]
  - [Finish]
  - [Next]
  - [Add] > select [custom monitor] as [Type] > input *genw-VMn* as [Name] > [Next]
  - select [Active] as [Monitoring Timig] > [Browse] > select [exec-VMn] > [OK] > [Next]
  - [Replace] > select *vm-monitor.pl* >  
    input */opt/nec/clusterpro/log/genw-VMn.log* as [Log Output Path] >  
    Check [Rotate Log] > [Next]
  - select [Executing failover to the recovery target] > [Browse] > select [failvoer-VMn] > [OK] > [Finish]
  - [Finish] > [Yes]
  - [File] menu > [Apply the Configuration File]
  
  - on both node (vma01, vma02)
    - setup root user credential for both ESXi by using /usr/lib/vmware-vcli/apps/general/credstore_admin.pl

    		# /usr/lib/vmware-vcli/apps/general/credstore_admin.pl add -s {IP_of_esxi01} -u root -p {password}

  - on vma01
    - Get the path information for the VMn with the command
    
    		# vmware-cmd --server 10.0.0.1 -U root -l 
    		
    		/vmfs/volumes/588b1739-87411a6f-618f-002421a9b4be/cent7/cent7.vmx

    - copy *vmconf.pl* to /opt/nec/clusterpro/scripts/failover-VMn/exec-VMn/vmconf.pl
    - edit *vmconf.pl*

###
### to be edited
###
  
#### On Cluster Manager
  - Change to [Operation Mode] > [Service] menu > [Start Cluster]
