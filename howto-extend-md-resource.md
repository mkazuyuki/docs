# How to extend MD resource in the iSCSI Target Cluster

----

[ECX Reference Guide][1] P.1331 "Changing offset or size of a partition on mirror disk resource" describes the method to extend MD resource. However its flow is **backup**, resize, format and **restore**.

This document describes how to extend MD resource without (re)format.

[1]:http://www.nec.com/en/global/prod/expresscluster/en/support/Linux/L33_RG_EN_05.pdf

----

## Steps to extend the data partition of the MD resource

1. On the both VM, set the cluster not to start automatically
	
		# systemctl disable clusterpro
		# systemctl disable clusterpro_md

	On either of the VM, shutdown the cluster

		# clpstdn

	The both nodes become power-off

2. On the both VM, extend the virtual hdd (.vmdk) which contains data-partition by vSphere Client then power-on the VM.

	https://kb.vmware.com/selfservice/microsites/search.do?cmd=displayKC&docType=kc&docTypeID=DT_KB_1_1&externalId=1007266

3. extend the data-partition of the MD resource
	
		# fdisk /dev/sdb
		# resize2fs /dev/sdb2

	The following is a quotation from man page of resize2fs(8) as a reference.

	> The resize2fs program does not manipulate the size of partitions. If you wish to enlarge a filesystem, you must make sure you can expand the size of the underlying partition first. This can be done using fdisk(8) by deleting the partition and recreating it with a larger size or using lvextend(8), if you're using the logical volume manager lvm(8). When recreating the partition, make sure you create it with the same starting disk cylinder as before! Otherwise, the resize operation will certainly not work, and you may lose your entire filesystem. After running fdisk(8), run resize2fs to resize the ext2 filesystem to use all of the space in the newly enlarged partition.

	The followings are other reference for extending the a logical volume (data-partition) in a VM.

	https://kb.vmware.com/selfservice/search.do?cmd=displayKC&docType=kc&docTypeID=DT_KB_1_1&externalId=1004071
	https://kb.vmware.com/selfservice/search.do?cmd=displayKC&docType=kc&docTypeID=DT_KB_1_1&externalId=1006371

4. initialize the cluster-partition of the MD resource. (Note : not for data-partition but for cluster-partition)

		# clpmdinit --create force <Mirror_disk_resource_name>

5. On the both VM, set the cluster to start automatically then reboot.

		# systemctl enable clusterpro
		# systemctl enable clusterpro_md
		# reboot

	The servers are started as a cluster.

6. The same process as the initial mirror construction at cluster creation is performed after a cluster is started. Run the following command or use the WebManager to check if the initial mirror construction is completed.

		# clpmdstat --mirror <Mirror_disk_resource_name>
