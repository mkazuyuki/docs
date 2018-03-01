#!/usr/bin/perl -w
#
# Script for monitoring the Virtual Machine
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

# IP addresses of VMkernel port.
my $vmk1 = "%%VMK1%%";
my $vmk2 = "%%VMK2%%";

# IP addresses of vMA VMs
my $vma1 = "%%VMA1%%";
my $vma2 = "%%VMA2%%";

#-------------------------------------------------------------------------------
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
my $cfg_path = "";
my @lines = ();
my $vmname = "";
my $r = 0;
foreach(@cfg_paths){
	# VM name to be outputted on log.
	$vmname = $_;
	$vmname =~ s/^(.*\/)(.*)(\.vmx)/$2/;
	if (&Monitor($_)){
		$r = 1;
	}
}
exit $r;
#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
sub Monitor {
	my $vmop = "gettoolslastactive";
	my $opn_ret;
	my $line;
	$cfg_path = shift;

	&execution("$vmcmd '$cfg_path' $vmop");
	if ($lines[0] =~ /^$vmop\(\)\s=\s(.+)$/) {

		# vmware-cmd <config_file_path> gettoolslastactive
		# 0 -- VMware Tools are not installed or not running.
		# 1 -- Guest operating system is responding normally.
		# 5 -- Intermittent heartbeat. There might be a problem with the guest operating system.
		# 100 -- No heartbeat. Guest operating system might have stopped responding

		if ($1 == 0){
			&Log("[W] [$vmname]\tVMware Tools are not installed or not running.\n");
		} elsif ($1 == 1) {
			&Log("[I] [$vmname]\tGuest OS is responding normally.\n");
			return 0;
		} elsif ($1 == 5) {
			&Log("[W] [$vmname]\tIntermittent heartbeat. There might be a problem with the guest OS.\n");
			return 0;
		} elsif ($1 == 100) {
			&Log("[E] [$vmname]\tNo heartbeat. Guest OS might have stopped responding.\n");
		} else {
			&Log("[E] [$vmname]\tUnknown response [" . $1 . "]\n");
		}
	}
	#elsif ($lines[0] =~ /No virtual machine found./) {
	#	# The VM might active on another ESXi and might be good to issue failover.
	#	# But there was a case (e.g. just after power on the VM) that
	#	# the VM exist on local ESXi inspite of the response "No virtual machine found".
	#}

	if (&IsEqualState($state{"VM_EXECUTION_STATE_ON"})) {
		# The VM states is powered on
		return 0;
	} else {
		# Issue failover when the VM is not pwered on
		&Log("[E] Execution state of [$vmname] is not ON.");
		return 1;
	}
}

#-------------------------------------------------------------------------------
sub IsEqualState {
	my $vmop = "getstate";
	my $state = shift;
	my $ret = 0;
	my $opn_ret;

	&execution($vmcmd . " '" . $cfg_path . "' " . $vmop);
	if ($lines[0] =~ /^$vmop\(\)\s=\s(.+)$/){
		$ret = 1 if ($1 eq $state);
		&Log("[D] [IsEqualState] [$vmname] at [$vmk] VM execution state is [$1].\n");
	}else{
		&Log("[E] [IsEqualState] [$vmname] at [$vmk] could not get VM execution state.\n");
	}
	return $ret;
}

#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	&Log("[D] executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	@lines = <$h>;

	foreach (@lines) {
		chomp;
		&Log("[D]\t$_\n");
	}

	close($h);
	&Log(sprintf("[D] result ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	return $?;
}

#-------------------------------------------------------------------------------
sub Log {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
	print "$date $_[0]";
	return 0;
}