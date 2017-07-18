#!/usr/bin/perl -w
#
# Script for power off the Virtual Machine
#
use strict;
use FindBin;
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
# The interval to check the vm status. (second)
my $interval = 5;
# The miximum count to check the vm status.
my $max_cnt = 100;
#-------------------------------------------------------------------------------
# Global values
my $cfg_path = "";
my $vmname = "";
my $vmk = "";

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
my $vmcmd = "/usr/bin/vmware-cmd --server $vmk --username root";
$ENV{"HOME"} = "/root";
&Log("[D] [$vmcmd]\n");

# VM execution state map
my %state = (
		"VM_EXECUTION_STATE_ON" => "on",
		"VM_EXECUTION_STATE_OFF" => "off",
		"VM_EXECUTION_STATE_SUSPENDED" => "suspended",
		"VM_EXECUTION_STATE_STUCK" => "stuck",
		"VM_EXECUTION_STATE_UNKNOWN" => "unknown"
	    );
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
	if (&IsPoweredOn()){
		if (&PowerOff()){
			if (!&WaitPoweredOffDone()){
				$r = 1;
			}
		}else{
			$r = 1;
		}
	}
	if (&UnRegisterVm()){
		next;
		#exit 0;
	}else{
		$r = 1;
	}
}
exit $r;
#-------------------------------------------------------------------------------
# Functions
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
	my $line;
	&Log("[D] [$vmcmd $cfg_path $vmop]\n");
	$opn_ret = open(my $fh, $vmcmd . " \"" . $cfg_path . "\" " . $vmop . " 2>&1 |");
	if (!$opn_ret){
		&Log("[E] [$vmname] at [$vmk]: $vmcmd $vmop could not be executed.\n");
		return 0;
	}
	$line = <$fh>;
	if (defined($line)){
		chomp($line);
		if ($line =~ /^$vmop\(\)\s=\s(.+)$/){
			$ret = 1 if ($1 eq $state);
			&Log("[D] [$vmname] at [$vmk]: VM execution state is $1.\n");
		}else{
			&Log("[E] [$vmname] at [$vmk]: Could not get VM execution state: $line\n");
		}
	}
	close($fh);
	return $ret;
}
#-------------------------------------------------------------------------------
sub PowerOff{
	my $ret;
# Soft stop.
	$ret = &PowerOffOpMode("soft");
# Hard stop if Soft stop failed.
	if (!$ret){
		$ret = &PowerOffOpMode("hard");
	}
	return $ret;
}
#-------------------------------------------------------------------------------
sub PowerOffOpMode{
	my $vmop = "stop";
	my $powerop_mode = shift;
	my $ret = 0;
	my $opn_ret;
	my $line;
	return 0 if ($powerop_mode !~ /^hard|soft$/);
	&Log("[D] [" . $vmcmd . " \"" . $cfg_path . "\" " . $vmop . " " . $powerop_mode . "]\n");
	$opn_ret = open(my $fh, $vmcmd . " \"" . $cfg_path . "\" " . $vmop . " " . $powerop_mode . " 2>&1 |");
	if (!$opn_ret){
		&Log("[E] [$vmname] at [$vmk]: $vmcmd $vmop $powerop_mode could not be executed.\n");
		return 0;
	}
	$line = <$fh>;
	if (defined($line)){
		chomp($line);
		if ($line =~ /^$vmop\(\)\s=\s(.+)$/){
			if ($1 == 1){
				$ret = 1;
				&Log("[I] [$vmname] at [$vmk]: Stopped. ($powerop_mode)\n");
			}else{
				&Log("[E] [$vmname] at [$vmk]: Could not stop ($powerop_mode) VM: $line\n");
			}
		}else{
			&Log("[E] [$vmname] at [$vmk]: Could not stop ($powerop_mode) VM: $line\n");
		}
	}else{
		if ($powerop_mode eq "soft"){
			$ret = 1;
			&Log("[I] [$vmname] at [$vmk]: Stopped. ($powerop_mode)\n");
		}
	}
	close($fh);
	return $ret;
}
#-------------------------------------------------------------------------------
sub WaitPoweredOffDone{
	for (my $i = 0; $i < $max_cnt; $i++){
		if (&IsEqualState($state{"VM_EXECUTION_STATE_OFF"})){
			&Log("[I] [$vmname] at [$vmk]: Powered off done. ($i)\n");
			return 1;
		}
		&Log("[I] [$vmname] at [$vmk]: Waiting peowered off. ($i)\n");
		sleep $interval;
	}
	&Log("[E] [$vmname] at [$vmk]: Not powered off done. ($max_cnt)=(wait count max)\n");
	return 0;
}
#-------------------------------------------------------------------------------
sub UnRegisterVm{
	my $svop = "-s unregister";
	my $vmcmd_list = $vmcmd . " -l";
	my @vmlist = `$vmcmd_list`;
	my $ret = 0;
	my $opn_ret;
	my $flag = 0;
	my $line;
	foreach (@vmlist){
		#if (/$cfg_path/){
		chomp;
		if ($cfg_path eq $_){
			$flag = 1;
		}
	}
	if ($flag == 0){
		&Log("[I] [$vmname] at [$vmk] already unregistered.\n");
		return 1;
	}else{
		$opn_ret = open(my $fh, $vmcmd . " " . $svop . " \"" . $cfg_path . "\" 2>&1 |");
		if (!$opn_ret){
			&Log("[E] [$vmname] at [$vmk]: $vmcmd $svop could not be executed.\n");
			return 0;
		}
		$line = <$fh>;
		if (defined($line)){
			$ret = 1;
			&Log("[I] [$vmname] at [$vmk]: Unregistered.\n");
		}else{
			$ret = 0;
			&Log("[E] [$vmname] at [$vmk]: Could not unregister VM: $line\n");
		}
		close($fh);
	}
	return $ret;
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
