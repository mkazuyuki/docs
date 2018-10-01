# Configuration Check List
|No.|Item|check|
|---|--- |---  |
|  1| ECX MD resource "Mount Point" is same as iSCSI Target "backstore" file path. | Check "Mount Point" parameter of MD resource and output of "targetcli ls" command. ||
|  2| Path to .vmx file is enclosed by single quotation ( ' ) in the start.sh of vMA Cluster. | Check each start.sh in failover-groups of vMA Cluster. ||
|  3| vmware-cmd, esxcli and ssh command can execute without inputting password. | vmware-cmd ||
|  4| vMA VMs are registered on ESXi as 'vSphere Management Assistant (vMA)01' on primary and 'vSphere Management Assistant (vMA)02' on secondary. |Chekc vMA VMAs name on ESXi inventory on vSphere Client|
|  5| MD on iSCSI is ext4 and should be formatted with " mkfs -t ext4 -O -6bit,-uninit_bg DATA_PARTITION_DEVICE_NAME ". | "tune2fs -l" then "64bit" and "uninit_bg" flag disabled. |
|  6| Property of Port Group > Network Label is the same across both ESXi.<br> Otherwise, "Network Connection" of "Network Adapter N" of UCVM will be empty after failover and the UCVM becomes impossible to communicate. | Check the Property of Port Group > Network Label on both ESXi. |
|  7| The default of vswitch for phone devices should be vSwitch0 so that genw-nic-link monitors the link status of the NICs which are the upinks for the vswitch. | Remove the LAN cable(s) connecting to the vswitch through the vmnic(s). Check whether genw-nic-link detect it. |
