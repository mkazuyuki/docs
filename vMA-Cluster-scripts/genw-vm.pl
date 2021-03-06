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
'/vmfs/volumes/58a7297f-5d0c41f3-b7a5-000c2964975f/cent7/cent7.vmx'
);

# IP addresses of VMkernel port.
my $vmk1 = "10.0.0.1";
my $vmk2 = "10.0.0.2";

# IP addresses of vMA VMs
my $vma1 = "10.0.0.21";
my $vma2 = "10.0.0.22";

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
#&Log("[I] [$vmcmd][" . $ENV{"HOME"} ."]\n");

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
my $vmname = "";
my $r = 0;
foreach(@cfg_paths){
	# VMname to be outputted on log.
	$vmname = $_;
	$vmname =~ s/^(.*\/)(.*)(\.vmx)/$2/;
	#system("\"ulimit\" -s unlimited");
	if (&Monitor($_)){
		$r = 1;
	}
}
exit $r;
#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
sub Monitor{
	my $vmop = "gettoolslastactive";
	my $ret = -1;
	my $opn_ret;
	my $line;
	my $cfg_path = shift;
	#&Log("[D] executing [$vmcmd \"$cfg_path\" $vmop]\n");
	$opn_ret = open(my $fh, "$vmcmd \"$cfg_path\" $vmop 2>&1 |");
	if (!$opn_ret){
		&Log("[E] [$vmname] at [$vmk] [$vmcmd $vmop] could not be executed.\n");
		return -1;
	}
	$line = <$fh>;
	if (defined($line)){
		chomp($line);
		if ($line =~ /^$vmop\(\)\s=\s(.+)$/){
			$ret = $1;
		}else{
			&Log("[E] [$vmname] at [$vmk] Could not get VM heartbeat count: [$line]\n");
			if ($line =~ /No virtual machine found./){
				# Issue failover when VMn active on another ESXi
				return 1;
			}
		}
	}
	close($fh);

	# vmware-cmd <config_file_path> gettoolslastactive
	# 0 -- VMware Tools are not installed or not running.
	# 1 -- Guest operating system is responding normally.
	# 5 -- Intermittent heartbeat. There might be a problem with the guest operating system.
	# 100 -- No heartbeat. Guest operating system might have stopped responding
	if ($ret == 0){
		&Log("[W] [$vmname]\tVMware Tools are not installed or not running.\n");
		return 0;
	} elsif ($ret == 1) {
		&Log("[I] [$vmname]\tGuest OS is responding normally.\n");
		return 0;
	} elsif ($ret == 5) {
		&Log("[W] [$vmname]\tIntermittent heartbeat. There might be a problem with the guest OS.\n");
		return 0;
	} elsif ($ret == 100) {
		&Log("[E] [$vmname]\tNo heartbeat. Guest OS might have stopped responding.\n");
		return -1;
	}
}
#-------------------------------------------------------------------------------
sub Log{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min,
	   $sec;
	print "$date $_[0]";
	return 0;
}
