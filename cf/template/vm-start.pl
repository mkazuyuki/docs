#!/usr/bin/perl -w
#
# Script for power on the Virtual Machine
#
use strict;
#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
# The path to VM configuration file. This must be absolute UUID-based path.
# like "/vmfs/volumes/<datastore-uuid>/vm1/vm1.vmx";
my @cfg_paths = (
'%%VMX%%'
);

# The HBA name to connect to iSCSI Datastore.
my $vmhba1 = "%%VMHBA1%%";
my $vmhba2 = "%%VMHBA2%%";

# The Datastore name which the VM is stored.
my $datastore = "%%DATASTORE%%";

# IP addresses of VMkernel port.
my $vmk1 = "%%VMK1%%";
my $vmk2 = "%%VMK2%%";

# IP addresses of vMA VMs
my $vma1 = "%%VMA1%%";
my $vma2 = "%%VMA2%%";

#-------------------------------------------------------------------------------
# The interval to check the storage status. (second)
my $storage_check_interval = 3;
# The interval to check the vm status. (second)
my $interval = 1;
# The miximum count to check the vm power status.
my $max_cnt = 100;
# The timeout to start the vm. (second)
my $start_to = 10;
# The interval for power on failure. (second)
my $pwron_interval = 10;
#-------------------------------------------------------------------------------
# Global values
my $vmk = "";
my $cfg_path = "";
my $vmname = "";
my $vmhba = "";
my @lines = ();

# VM execution state map
my %state = (
	"VM_EXECUTION_STATE_ON" => "on",
	"VM_EXECUTION_STATE_OFF" => "off",
	"VM_EXECUTION_STATE_SUSPENDED" => "suspended",
	"VM_EXECUTION_STATE_STUCK" => "stuck",
	"VM_EXECUTION_STATE_UNKNOWN" => "unknown"
);

my $tmp = `ip address | grep $vma1/`;
if ($? == 0) {
	$vmk = $vmk1;
	$vmhba = $vmhba1;
} else {
	$tmp = `ip address | grep $vma2/`;
	if ($? == 0) {
		$vmk = $vmk2;
		$vmhba = $vmhba2;
	} else {
		&Log("[E] Invalid configuration (Mananegment host IP could not be found).\n");
		exit 1;
	}
}

# VM operation command path
my $vmcmd = "/usr/bin/vmware-cmd --server $vmk --username root";
$ENV{"HOME"} = "/root";
#&Log("[I] [/usr/bin/vmware-cmd --server $vmk --username root][" . $ENV{"HOME"} ."]\n");

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
my $r = 0;
foreach (@cfg_paths){
	# VMname to be output on log.
	$vmname = $_;
	$vmname =~ s/^(.*\/)(.*)(\.vmx)/$2/;
	$cfg_path = $_;
	&Log("[I] [$vmname][$cfg_path]\n");
	while (!&IsStorageReady()){
		sleep $storage_check_interval;
	};
	exit 1 if (&RegisterVm());
	if (&IsPoweredOn()){
		next;
	}
	if (&PowerOn()){
		if (&WaitPoweredOnDone()){
			next;
		} else {
			$r = 1;
			sleep $pwron_interval;
		}
	} else {
		$r = 1;
		sleep $pwron_interval;
	}
}
exit $r;
#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
sub IsStorageReady{
	my $device = "";
	&execution("esxcli -s $vmk -u root storage vmfs extent list");
	foreach (@lines) {
		chomp;
		&Log("[D][IsStorageReady] $_\n");
		if(/^$datastore\s+(.+?\s+){2}(.+?)\s.*/){
			$device = $2;
			&Log("[D][IsStorageReady] \tdatastore [$datastore] = device [$device]\n");
			last;
		}
	}
	if($device eq ""){
		&Log("[E][IsStorageReady] \tdatastore [$datastore] not found\n");
		&execution("esxcli -s $vmk -u root storage core adapter rescan --adapter $vmhba");
		return 0;
	}

	my $ret = -1;
	&execution("esxcli -s $vmk -u root storage core path list -d $device");
	foreach (@lines) {
		chomp;
		if(/   State: (.*)$/){
			&Log("[D][IsStorageReady] \t[$_]\n");
			if($1 eq "active"){
				$ret = 1;
			} else {
				$ret = 0;
			}
			last;
		}
	}
	if($ret == -1){
		&Log("[E][IsStorageReady] datastore state for [$datastore] not found\n");
		return 1;
	}
	return $ret;
}
#-------------------------------------------------------------------------------
sub RegisterVm{
	my $vmcmd_list = $vmcmd . " -l";
	my $vmid = "";

	# Checking inventory
	################################
	&execution($vmcmd_list);
	foreach(@lines){
		chomp;
		&Log("[D][RegisterVm]\t[$_]\n");
		if ($cfg_path eq $_){
			&Log("[I] [$vmname] at [$vmk] already registered.\n");
			return 0;
		}
	}

	# Registering VM
	################################
	my $cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd solo/registervm \'$cfg_path\' 2>&1\"";
	&execution($cmd);
	foreach(@lines){
		chomp;
		&Log("[D][RegisterVm] \t[$_]\n");
		if (/msg = \"The specified key, name, or identifier '(\d+)' already exists.\"/) {
			$vmid = $1;
		}
	}
	if ($vmid eq "") {
		&Log("[I][RegisterVm] [$vmname] at [$vmk] registered\n");
		return 0;
	}

	# Failed to register due to invalid VM existence.
	# Unregistering the invalid VM.
	################################
	$cmd = "ssh -i ~/.ssh/id_rsa $vmk \'vim-cmd vmsvc/unregister $vmid\'";
	&execution($cmd);
	foreach(@lines){
		chomp;
		&Log("[D][RegisterVm]\t[$_]\n");
	}

	# Retrying to register VM
	################################
	#$cmd = "$vmcmd $svop \'$cfg_path\' 2>&1";
	$vmid = "";
	$cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd solo/registervm \'$cfg_path\' 2>&1\"";
	&execution($cmd);
	foreach(@lines){
		chomp;
		if(/^(\d+?)$/){
			$vmid = $1;
		}
		&Log("[D][RegisterVm] \t[" . $_ ."]\n");
	}
	if($vmid eq ""){
		&Log("[E][RegisterVm] [$vmname] at [$vmk] failed to regiester\n");
		return 1;
	}
	&Log(sprintf("[I][RegisterVm]\t[$vmname][$vmid] at [$vmk] registered\n"));
	return 0;
}
#-------------------------------------------------------------------------------
sub IsPoweredOn{
	if (&IsEqualState($state{"VM_EXECUTION_STATE_ON"})){
		return 1;
	}else{
		return 0;
	}
}
#-------------------------------------------------------------------------------
sub IsEqualState{
	my $vmop = "getstate";
	my $state = shift;
	my $ret = 0;
	my $opn_ret;
	$opn_ret = open(my $fh, $vmcmd . " \"" . $cfg_path . "\" " . $vmop . " 2>&1 |");
	if (!$opn_ret){
		&Log("[E][IsEqualState] [$vmname] at [$vmk]: $vmcmd $vmop could not be executed.\n");
		return 0;
	}
	my $line = <$fh>;
	if (defined($line)){
		chomp($line);
		if ($line =~ /^$vmop\(\)\s=\s(.+)$/){
			$ret = 1 if ($1 eq $state);
			&Log("[D][IsEqualState] [$vmname] at [$vmk] VM execution state is [$1].\n");
		}else{
			&Log("[E][IsEqualState] [$vmname] at [$vmk] could not get VM execution state: [$line]\n");
		}
	}
	close($fh);
	return $ret;
}
#-------------------------------------------------------------------------------
sub PowerOn{
	my $vmop = "start";
	my $ret = 0;
	my $opn_ret;
	my $line;
	&Log("[D][PowerOn] executing [" . $vmcmd . " \"" . $cfg_path . "\" " . $vmop . " 2>&1]\n");
	$opn_ret = open(my $fh, $vmcmd . " \"" . $cfg_path . "\" " . $vmop . " 2>&1 |");
	if (!$opn_ret){
		&Log("[E][PowerOn] [$vmname] at [$vmk] $vmcmd $vmop could not be executed.\n");
		return 0;
	}
	eval{
		local $SIG{ALRM} = sub { die "timeout" };
		alarm($start_to);
		$line = <$fh>;
		alarm(0);
	};
	alarm(0);
	if ($@){
		if($@ =~ /timeout/){
			&Log("[E][PowerOn] [$vmname] at [$vmk] could not start VM: timeout($start_to second)\n");
			if (&IsEqualState($state{"VM_EXECUTION_STATE_STUCK"})){
				$ret = 1 if (&ResolveVmStuck());
			}
		}
	}
	else{
		if (defined($line)){
			chomp($line);
			if ($line =~ /^$vmop\(\)\s=\s(.+)$/){
				if ($1 == 1){
					$ret = 1;
					&Log("[I][PowerOn] [$vmname] at [$vmk] started.\n");
				}else{
					&Log("[E][PowerOn] [$vmname] at [$vmk] could not start VM: [$line]\n");
				}
			}else{
				&Log("[E][PowerOn] [$vmname] at [$vmk] could not start VM: [$line]\n");
				if (&IsEqualState($state{"VM_EXECUTION_STATE_STUCK"})){
					$ret = 1 if (&ResolveVmStuck());
				}
			}
		}
		close($fh);
	}
	return $ret;
}
#-------------------------------------------------------------------------------
sub ResolveVmStuck{
	my $vmop = "answer";
	my $ret = 0;
	my $opn_ret;
	my $line;
	$opn_ret = open(my $fh, "| ". $vmcmd . " \"" . $cfg_path . "\" " . $vmop);
	if (!$opn_ret){
		&Log("[E] [$vmname] at [$vmk]: $vmcmd $vmop could not be executed.\n");
		return 0;
	}
	# Answering "1) I _moved it" to keep vm config.
	print($fh "1\n");
	close($fh);
	if (&IsEqualState($state{"VM_EXECUTION_STATE_STUCK"})){
		&Log("[E] [$vmname] at [$vmk]: VM stuck could not be resolved.\n");
	}else{
		$ret = 1;
		&Log("[I] [$vmname] at [$vmk]: VM stuck is resolved.\n");
	}
	return $ret;
}
#-------------------------------------------------------------------------------
sub WaitPoweredOnDone{
	for (my $i = 0; $i < $max_cnt; $i++){
		if (&IsEqualState($state{"VM_EXECUTION_STATE_ON"})){
			&Log("[I] [$vmname] at [$vmk]: Powered on done. ($i)\n");
			return 1;
		}
		sleep $interval;
	}
	&Log("[E] [$vmname] at [$vmk]: Not powered on done. ($max_cnt)\n");
	return 0;
}
#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	&Log("[D] executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	@lines = <$h>;
	close($h); 
	&Log(sprintf("[D] result ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	return $?;
}
#-------------------------------------------------------------------------------
sub Log{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
	print "$date $_[0]";
	return 0;
}
