Reference Guide P.1331 "Changing offset or size of a partition on mirror disk resource" describes the method.
However It is backup, resize, format and restore, so, not match to your intention.

- http://www.nec.com/en/global/prod/expresscluster/en/support/Linux/L33_RG_EN_05.pdf

Overall steps for extending the data partition of the MD resource are as belows.

1. stop the cluster
2. extend the data-partition
3. initialize the cluster-partition
4. initiate initial mirror construction

Information below could be used for extending vmdk and ext4 file system of the nodes in iSCSI Target Cluster.
This could be used for extending the vmdk and file system for the MD resource.

- https://kb.vmware.com/selfservice/microsites/search.do?cmd=displayKC&docType=kc&docTypeID=DT_KB_1_1&externalId=1007266
- https://kb.vmware.com/selfservice/search.do?cmd=displayKC&docType=kc&docTypeID=DT_KB_1_1&externalId=1004071
