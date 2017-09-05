# Configuration Check List
|No.|Item|check|
|---|--- |---  |
|  1| ECX MD resource "Mount Point" is same as iSCSI Target "backstore" file path. | Check "Mount Point" parameter of MD resource and output of "targetcli ls" command. ||
|  2| Path to .vmx file is enclosed by single quotation ( ' ) in the start.sh of vMA Cluster. | Check each start.sh in failover-groups of vMA Cluster. ||
|  3| vmware-cmd, esxcli and ssh command can execute without inputting password. | vmware-cmd ||
