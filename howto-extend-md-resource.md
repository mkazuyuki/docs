# How to extend MD resource in the iSCSI Target Cluster running on ESXi

----

[ECX Reference Guide][1] P.1331 "Changing offset or size of a partition on mirror disk resource" describes the method to extend MD resource. However its rough flow is backup, resize, **format** then restore. Yes, this flow includes "format" which you may dislike .

This document describes how to extend MD resource without (re)format.

[1]:http://www.nec.com/en/global/prod/expresscluster/en/support/Linux/L33_RG_EN_05.pdf

----

## Steps to extend the data partition of the MD resource
1. On Cluster Manager GUI, Make sure [Execute initial mkfs] is set to OFF.

	1. open Cluster Manager GUI
	2. change to [Config Mode] ( from [Operation Mode] )
	3. right click [md1] icon in left pane > [properties] 
	4. [Detailes] tab > [Tuning] button
	5. [Mirror] tab
	6. Uncheck [Execute initial mkfs] > [OK]
	7. [OK]
	8. if you changed [Execute initial mkfs] parameter in above  
	   [File] menu > [Apply Configuration] 
	
2. On the both VM console, set the cluster services not to start automatically.

		# systemctl disable clusterpro
		# systemctl disable clusterpro_md

3. On either of the VM console, issue *clpstdn* command to shutdown the cluster.

		# clpstdn

	The both nodes become power-off

4. On vSphere Client, for both VM, extend the size of the virtual HDD (.vmdk) which contains data-partition of the MD resource, then power-on the VM.

	https://kb.vmware.com/selfservice/microsites/search.do?cmd=displayKC&docType=kc&docTypeID=DT_KB_1_1&externalId=1007266

5. On the both VM console, extend the data-partition of the MD resource.

		# fdisk /dev/sdb
		# resize2fs /dev/sdb2

	The following is a quotation from man page of resize2fs(8) as a reference.

	> The resize2fs program does not manipulate the size of partitions. If you wish to enlarge a filesystem, you must make sure you can expand the size of the underlying partition first. This can be done using fdisk(8) by deleting the partition and recreating it with a larger size or using lvextend(8), if you're using the logical volume manager lvm(8). When recreating the partition, make sure you create it with the same starting disk cylinder as before! Otherwise, the resize operation will certainly not work, and you may lose your entire filesystem. After running fdisk(8), run resize2fs to resize the ext2 filesystem to use all of the space in the newly enlarged partition.

	The followings are other reference for extending the a logical volume (data-partition) in a VM.

	https://kb.vmware.com/selfservice/search.do?cmd=displayKC&docType=kc&docTypeID=DT_KB_1_1&externalId=1004071
	https://kb.vmware.com/selfservice/search.do?cmd=displayKC&docType=kc&docTypeID=DT_KB_1_1&externalId=1006371

6. On either of the VM console, initialize the cluster-partition of the MD resource. (Note : not for data-partition but for cluster-partition)

		# clpmdinit --create force <Mirror_disk_resource_name>

7. On the both VM console, set the cluster services to start automatically then reboot.

		# systemctl enable clusterpro
		# systemctl enable clusterpro_md
		# reboot

	The servers are started as a cluster.

8. The same process as the initial mirror construction at cluster creation is performed after a cluster is started.
   Run the following command or use the Cluster Manager to check if the initial mirror construction is completed.

		# clpmdstat --mirror <Mirror_disk_resource_name>
