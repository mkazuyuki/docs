#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

# The path to VM configuration file. This must be absolute UUID-based path.
our $cfg_path = "/vmfs/volumes/587e4364-7e2a2a4c-ca0d-58c2320dc360/SV9500 Primary Node (V2U-00.08 ACDP V2U-05 NEW)/SV9500 Primary Node (V2U-00.08 ACDP V2U-05 NEW).vmx";

# The path of the storage which the VM is stored.
our $datastore = "iSCSI";

# IP addresses of VMkernel port.
our $vmk1 = "10.0.12.76";
our $vmk2 = "10.0.12.77";

# IP addresses of Management VMs
our $vma1 = "10.0.10.202";
our $vma2 = "10.0.10.212";

1;
