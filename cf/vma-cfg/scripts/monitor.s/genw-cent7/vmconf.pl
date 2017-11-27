#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

# The path to VM configuration file. This must be absolute UUID-based path.
#our $cfg_path = "/vmfs/volumes/58a7297f-5d0c41f3-b7a5-000c2964975f/cent7/cent7.vmx";
#our @cfg_paths = (
#"/vmfs/volumes/58a7297f-5d0c41f3-b7a5-000c2964975f/cent7/cent7.vmx",
#"/vmfs/volumes/58a7297f-5d0c41f3-b7a5-000c2964975f/vm1/vm1.vmx"
#);
our @cfg_paths = (
"/vmfs/volumes/iSCSI/cent7/cent7.vmx",
"/vmfs/volumes/iSCSI/vm1/vm1.vmx"
);
# The path of the storage which the VM is stored.
our $datastore = "iSCSI";

# IP addresses for VM kernel port.
our $vmk1 = "192.168.137.51";
our $vmk2 = "192.168.137.52";

# IP addresses of Management VMs
our $vma1 = "192.168.137.205";
our $vma2 = "192.168.137.206";

1;
