# ESXi 6.5 update 1 configuration notes for ECX Host Clustering

- In spite of the port group `VM Netowrk HOGE` exists, the following message appears.

	"This VM is attached to a network portgroup `VM Network HOGE` that doesn't exist. Edit this VM and attach it to a different network."

	This happens on the portgroup which have a VMkernel NIC. As a workaround, having multiple port groups for the same vSwitch solve the situation. One portgroup for the VMkernel NIC and another portgroup for the VM clients all on the same vswitch. ([Reference](https://communities.vmware.com/thread/547389))

# ESXi configuration notes for ECX Host Clustering
- All the nodes in vMA Cluster and iSCSI Cluster should be configured to boot automatically when ESXi starts.
- The network for iSCSI and Data Mirroring should use physically indepenent netowrk if possible. Configure logically independent at least.
- Add VMkernel port for iSCSI communication.
- Try to invalidate TSO, LRO and Jumbo Frame if iSCSI performance is not enough.

	- Disabling TSO (TCP Segmentation Offload), LRO (Large Receive Offload)

		-ESXiA

			[root@localhost:~] esxcli system settings advanced list -o /Net/UseHwTSO
			   Path: /Net/UseHwTSO
			   Type: integer
			   Int Value: 1
			   Default Int Value: 1
			   Min Value: 0
			   Max Value: 1
			   String Value:
			   Default String Value:
			   Valid Characters:
			   Description: When non-zero, use pNIC HW TSO offload if available
			[root@localhost:~] esxcli system settings advanced set -o /Net/UseHwTSO -i 0
			[root@localhost:~] esxcli system settings advanced set -o /Net/UseHwTSO6 -i 0
			[root@localhost:~] esxcli system settings advanced set -o /Net/TcpipDefLROEnabled -i 0
			[root@localhost:~]

		-ESXiB

			[root@localhost:~] esxcli system settings advanced set -o /Net/UseHwTSO -i 0
			[root@localhost:~] esxcli system settings advanced set -o /Net/UseHwTSO6 -i 0
			[root@localhost:~] esxcli system settings advanced set -o /Net/TcpipDefLROEnabled -i 0
			[root@localhost:~]

- Configure ssh service to start automatically when ESXi start.

- genw-remote-node in vMA Cluster periodically executes "power on" for another vMA VM. And so, "suspend" the genw-remote-node before when intentionally shutdown the vMA VM
- genw-remote-node in vMA Cluster periodically executes "starting cluster service" for another vMA VM. And so, "suspend" the genw-remote-node before when intentionally stop the cluster service.

- The graceful shutdown procedure of both ESXi
  1. Issue *cluster shutdown* for the vMA Cluster
  2. Issue *cluster shutdown* for the iSCSI Cluster
  3. Issue *shutdown* for each the ESXi.

<!--
- vMA VM, iSCSI VM の自動起動設定
- iSCSI network と mirror network の分割
- iSCSI用 VMkernel port の追加
- TSO, LRO, Jumbo frame の無効化
- ssh サービスの自動起動設定
- vMA Cluster の genw-remote-node は
  - 対向 vMA VM の power off status を認識すると power on を実行する。従って、意図的に vMA VM を power off 状態にするときは、vMA Cluster の genw-remote-node を suspend する必要がある。
  - 対向 vMA VM で ECサービス の offline status を認識すると service start を実行する。従って、意図的に ECサービス を offline status にするときは、vMA Cluster の genw-remote-node を suspend する必要がある。
-->


<!--

2017/12/20

VMware-VMvisor-Installer-6.5.0.update01-5969303.x86_64.iso

VMware vSphere Hypervisor 6
VMware-VMvisor-Installer-201701001-4887370.x86_64.iso

1. Configuring BOTH ESXi

- Configure network
	- Assumption
		- Port group : VM Network, Management Network having vSwitch0
		- Virtual switch : vSwitch0
		- Physical NIC : vmnic[0..2]
	- Configuring
		- Virtual Switch > add *vSwitch1[1..2]* to have uplink to vmnic[1..2]
		- Port Group > add *VM Network [1..2]* to have vSwitch[1..2]
		- VMkernel NIC > add VMkernel NIC >  
		  *VM Network 1* as Port Group  
		  *Static* as IPv4 configuration  
		  *192.168.0.1* as Address  
		  *255.255.255.0* as Subnet Mask

- Configuring storage
	- Storage > [Adapter] tab > [iSCSI Configuration] > enabling iSCSI
		- set alias as *iqn.1998-01.com.vmware:1* for ESXi#1
		- set alias as *iqn.1998-01.com.vmware:2* for ESXi#2
		Then vmhba65 is added.
2. Configuring iSCSI VMs

	iqn.1998-01.com.vmware:1
-->
