#!/usr/bin/perl -w
#
# Script for power on the Virtual Machine
#
use strict;
##use FindBin;
#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
# The path to VM configuration file. This must be absolute UUID-based path.
# like "/vmfs/volumes/<datastore-uuid>/vm1/vm1.vmx";
our @cfg_paths = (
#'/vmfs/volumes/58a7297f-5d0c41f3-b7a5-000c2964975f/vm1/vm1.vmx'
'/vmfs/volumes/58a7297f-5d0c41f3-b7a5-000c2964975f/cent7/cent7.vmx'
);

# The Datastore name which the VM is stored.
our $datastore = "iSCSI";

# IP addresses of VMkernel port.
our $vmk1 = "10.0.0.1";
our $vmk2 = "10.0.0.2";

# IP addresses of vMA VMs
our $vma1 = "10.0.0.21";
our $vma2 = "10.0.0.22";

#-------------------------------------------------------------------------------
# If using vmconf.pl as configuration file, comment out the above configuration
# and comment in the below configuraiton.
##our @cfg_paths = ();
##our $datastore = "";
##our $vmk1 = "";
##our $vmk2 = "";
##our $vma1 = "";
##our $vma2 = "";
##require($FindBin::Bin . "/vmconf.pl");
#-------------------------------------------------------------------------------
# The interval to check the storage status. (second)
my $storage_check_interval = 3;
# The interval to check the vm status. (second)
my $interval = 1;
# The miximum count to check the vm power status.
my $max_cnt = 100;
# The timeout to start the vm. (second)
my $start_to = 10;
#-------------------------------------------------------------------------------
# Global values
my $vmk = "";
my $cfg_path = "";
my $vmname = "";

# VM execution state map
my %state = (
	"VM_EXECUTION_STATE_ON" => "on",
	"VM_EXECUTION_STATE_OFF" => "off",
	"VM_EXECUTION_STATE_SUSPENDED" => "suspended",
	"VM_EXECUTION_STATE_STUCK" => "stuck",
	"VM_EXECUTION_STATE_UNKNOWN" => "unknown"
);

my $tmp = `ip address | grep $vma1`;
if ($? == 0) {
	$vmk = $vmk1;
} else {
	$tmp = `ip address | grep $vma2`;
	if ($? == 0) {
		$vmk = $vmk2;
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
		}
	} else {
		$r = 1;
	}
}
exit $r;
#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
sub IsStorageReady{
	my $device = "";
	my $cmd = "esxcli -s $vmk -u root storage vmfs extent list";
	&Log("[D][IsStorageReady] executing [$cmd]\n");
	open(IN, $cmd . "|") or die "[E][IsStorageReady] esxcli failed to execute : [$!]";
	while(<IN>){
		chomp;
		&Log("[D][IsStorageReady] \t[$_]\n");
		if(/^$datastore\s+(.+?\s+){2}(.+?)\s.*/){
			$device = $2;
			&Log("[D][IsStorageReady] \tdatastore [$datastore] = device [$device]\n");
			last;
		}
	}
	close(IN) or &Log( $! ? "[E][IsStorageReady]\tclose failed ![$!]\n"
			      : "[E][IsStorageReady]\tcmd exit non-zero ?[$?]\n" );
	&Log(sprintf("[E][IsstorageReady] \t![%d] ?[%d]\n", $!, $?));
	if($device eq ""){
		&Log("[E][IsStorageReady] \tdatastore [$datastore] not found\n");
		return 0;
	}

	my $ret = -1;
	$cmd = "esxcli -s $vmk -u root storage core path list -d $device";
	&Log("[D][IsStorageReady] executing [$cmd]\n");
	open(IN, $cmd . "|") or die "[E][IsStorageReady] esxcli failed to execute.";
	while(<IN>){
		if(/   State: (.*)$/){
			chomp;
			&Log("[D][IsStorageReady] \t[$_]\n");
			if($1 eq "active"){
				$ret = 1;
			} else {
				$ret = 0;
			}
			last;
		}
	}
	close(IN) or &Log( $! ? "[E][IsStorageReady]\tclose failed ![$!]\n"
			      : "[E][IsStorageReady]\tcmd exit non-zero ?[$?]\n" );
	&Log(sprintf("[E][IsstorageReady] \t![%d] ?[%d]\n", $!, $?));
	if($ret == -1){
		&Log("[E][IsStorageReady] datastore state for [$datastore] not found\n");
		return 1;
	}
	return $ret;
}
#-------------------------------------------------------------------------------
sub RegisterVm{
	my $ret = 1;
	#my $svop = "-s register";
	my $vmcmd_list = $vmcmd . " -l";
	my $vmid = "";

	# Checking inventory
	################################
	&Log("[D][RegisterVm] executing [$vmcmd_list]\n");
	open(my $h, $vmcmd_list . " 2>&1 |") or die "[E][RegisterVm] execution failed [$!]";
	foreach (<$h>){
		chomp;
		&Log("[D][RegisterVm]\t[$_]\n");
		if ($cfg_path eq $_){
			&Log("[I] [$vmname] at [$vmk] already registered.\n");
			$ret = 0;
		}
	}
	close($h) or &Log( $! ? "[E][RegisterVm]\tclose failed ![$!]\n"
			      : "[E][RegisterVm]\tcmd exit non-zero ?[$?]\n" );
	&Log(sprintf("[E][RegisterVm]\t![%d] ?[%d]\n", $!, $?));
	return 0 if ($ret == 0);

	# Registering VM
	################################
	my $cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd solo/registervm \'$cfg_path\' 2>&1\"";
	&Log("[D][RegisterVm] executing [$cmd]\n");
	open($h, "$cmd |") or die "[E][RegisterVm] execution [$cmd] failed [$!]";
	while(<$h>){
		chomp;
		&Log("[D][RegisterVm] \t[$_]\n");
		if (/msg = \"The specified key, name, or identifier '(\d+)' already exists.\"/) {
			$vmid = $1;
		}
	}
	close($h) or &Log( $! ? "[E][RegisterVm]\tclose failed ![$!]\n"
			      : "[E][RegisterVm]\tcmd exit non-zero ?[$?]\n" );
	&Log(sprintf("[E][RegisterVm]\t![%d] ?[%d]\n", $!, $?));
	if ($vmid eq "") {
		&Log("[I][RegisterVm] [$vmname] at [$vmk] registered\n");
		return 0;
	}

	# Failed to register due to invalid VM existence.
	# Unregistering the invalid VM.
	################################
	$cmd = "ssh -i ~/.ssh/id_rsa $vmk \'vim-cmd vmsvc/unregister $vmid\'";
	&Log("[D][RegisterVm] executing [$cmd]\n");
	open($h, "$cmd |") or die "[E][RegisterVm] execution [$cmd] failed [$!]";
	while(<$h>){
		&Log("[D][RegisterVm]\t[$_]\n");
	}
	close($h) or &Log( $! ? "[E][RegisterVm]\tclose failed ![$!]\n"
			      : "[E][RegisterVm]\tcmd exit non-zero ?[$?]\n" );
	&Log(sprintf("[E][RegisterVm]\t![%d] ?[%d]\n", $!, $?));

	# Retrying to register VM
	################################
	#$cmd = "$vmcmd $svop \'$cfg_path\' 2>&1";
	$vmid = "";
	$cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd solo/registervm \'$cfg_path\' 2>&1\"";
	&Log("[D][RegisterVm] executing [$cmd]\n");
	open($h, "$cmd |") or die "[E][RegisterVm] execution [$cmd] failed [$!]";
	while(<$h>){
		chomp;
		if(/^(\d+?)$/){
			$vmid = $1;
		}
		&Log("[D][RegisterVm] \t[" . $_ ."]\n");
	}
	if(!close($h)){
		&Log( $! ? "[E][RegisterVm]\tclose failed ![$!]\n"
			 : "[E][RegisterVm]\tcmd exit non-zero ?[$?]\n" );
		&Log("[E][RegisterVm] [$vmname] at [$vmk] failed to regiester\n");
		return 1;
	}
	&Log(sprintf("[I][RegisterVm]\t![%d] ?[%d] [$vmname][$vmid] at [$vmk] registered\n", $!, $?));
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
sub Log{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
	print "$date $_[0]";
	return 0;
}
