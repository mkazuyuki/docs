#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

# The path of the storage which the VM is stored.
our $DatastorePath = "/vmfs/volumes/58a7297f-5d0c41f3-b7a5-000c2964975f";
our $DatastoreName = "iSCSI";

# IP addresses for VM kernel port.
our $vmk1 = "192.168.137.51";
our $vmk2 = "192.168.137.52";

# IP addresses of Management VMs
our $vma1 = "192.168.137.205";
our $vma2 = "192.168.137.206";

# The name of iSCSI Software Adaptes
our $vmhba1 = "vmhba33";
our $vmhba2 = "vmhba33";

1;
#-------------------------------------------------------------------------------
