#!/usr/bin/perl -w
#
# Script for power on the Virtual Machine
#
use strict;
use FindBin;
#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
# The interval to check the vm status. (second)
my $interval = 1;
# The miximum count to check the vm status.
my $max_cnt = 100;
# The timeout to start the vm. (second)
my $start_to = 10;
#-------------------------------------------------------------------------------
our $cfg_path = "";
our $vmk1 = "";
our $vmk2 = "";
our $vma1 = "";
our $vma2 = "";
require($FindBin::Bin . "/vmconf.pl");
# VMname to be output on log.
my $vmname = $cfg_path;
$vmname =~ s/^(.*\/)(.*)(\.vmx)/$2/;
# VM operation command path
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
&Log("[I] [/usr/bin/vmware-cmd --server $vmk --username root][" . $ENV{"HOME"} ."]\n");

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
exit 1 if (!&RegisterVm());
if (&IsPoweredOn()){
	exit 0;
} else {
	if (&PowerOn()){
		if (&WaitPoweredOnDone()){
			exit 0;
		} else {
			exit 1;
		}
	} else {
		exit 1;
	}
}
#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
sub RegisterVm{
	my $opn_ret;
	my $svop = "-s register";
	my $vmcmd_list = $vmcmd . " -l";

	&Log("[D] $vmcmd_list\n");

	$opn_ret = open(my $fh, $vmcmd_list . " 2>&1 |");

	#my @vmlist = `$vmcmd_list`;
	my @vmlist = <$fh>;
	close($fh);
	foreach (@vmlist){
		&Log("[D][RegisterVm] $_\n");
	}

	my $ret = 0;
	my $line;
	foreach (@vmlist){
		chomp;
		if ($cfg_path eq $_){
			&Log("[I] [$vmname] at [$vmk] already registered.\n");
			return 1;
		}
	}

	$opn_ret = open($fh, $vmcmd . " " . $svop . " \"" . $cfg_path . "\" 2>&1 |");
	if (!$opn_ret){
		&Log("[E] [$vmname] at [$vmk]: $vmcmd $svop could not be executed.\n");
		return 0;
	}
	$line = <$fh>;
	if (defined($line)){
		&Log("[I] [$vmname] at [$vmk] Registered: $line\n");
		$ret = 1;
	}else{
		&Log("[E] [$vmname] at [$vmk] Could not register VM: $line\n");
		$ret = 0;
	}
	close($fh);
	return $ret;
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
		&Log("[E] [$vmname] at [$vmk]: $vmcmd $vmop could not be executed.\n");
		return 0;
	}
	my $line = <$fh>;
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
sub PowerOn{
	my $vmop = "start";
	my $ret = 0;
	my $opn_ret;
	my $line;
	$opn_ret = open(my $fh, $vmcmd . " \"" . $cfg_path . "\" " . $vmop . " 2>&1 |");
	if (!$opn_ret){
		&Log("[E] [$vmname] at [$vmk]: $vmcmd $vmop could not be executed.\n");
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
			&Log("[E] [$vmname] at [$vmk]: Cound not start VM: timeout($start_to second)\n");
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
					&Log("[I] [$vmname] at [$vmk]: Started.\n");
				}else{
					&Log("[E] [$vmname] at [$vmk]: Cound not start VM: $1\n");
				}
			}else{
				&Log("[E] [$vmname] at [$vmk]: Cound not start VM: $line\n");
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
