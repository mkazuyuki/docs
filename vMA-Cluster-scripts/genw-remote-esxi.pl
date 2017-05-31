#!/usr/bin/perl -w
#
# Script for monitoring the Virtual Machine on standby ESXi
#
use strict;
use FindBin;
#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
our $DatastoreName = "";
our $vmk1 = "";
our $vmk2 = "";
our $vma1 = "";
our $vma2 = "";
our $vmhba1 = "";
our $vmhba2 = "";

require($FindBin::Bin . "/vmconf.pl");

# This line need for correct execution of vmware-cmd w/o password
$ENV{"HOME"} = "/root";

# VM operation command path
my $vmk = "";	# vmk local
my $vmkr = "";	# vmk remote
my $vmhba = "";
my $tmp = `ip address | grep $vma1`;
if ($? == 0) {
	$vmk  = $vmk1;
	$vmkr = $vmk2;
	$vmhba = $vmhba1;
} else {
	$vmk = $vmk2;
	$vmkr = $vmk1;
	$vmhba = $vmhba2;
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
&iscsiRecovery();

my $cmd = "clpstat --local";
my $noderemote = "";
my $nodecurr = "";
my @lines	= ();

&execution($cmd);
my $i;
for ($i=0; $i<$#lines; $i++){
	if ($lines[$i] =~ /<server>/){
		last;
	}
}
for ($i=$i+1; $i<$#lines; $i++){
	if ($lines[$i] =~ /^\s{4}(\S+) /) {
		$noderemote = $1;
	}
	elsif ($lines[$i] =~ /<group>/){
		last;
	}
}
for ($i=$i+1; $i<$#lines; $i++){
	if ($lines[$i] =~ /^\s{6}current.*: (.*)/) {
		$nodecurr = $1;
		last;
	}
	elsif ($lines[$i] =~ /<monitor>/){
		last;
	}
}
&Log("[D] remote[$noderemote] current[$nodecurr]\n");

#---------- 2017/05/28

if (($noderemote ne "") && ($noderemote eq $nodecurr)) {
	my $val = &Monitor();
	exit $val;
}
exit 0;

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
sub iscsiRecovery{
	my $ret = -1;
	#esxcli --server 192.168.137.52 iscsi session list --adapter=vmhba33
	my $cmd = "esxcli --server $vmk iscsi session list --adapter=$vmhba";
	&Log("[D][iscsiRecovery] executing [$cmd]\n");
	open(my $h, "$cmd |") or die "[E][iscsiRecovery]\texecution [$cmd] failed [$!]";
	while(<$h>){
		chomp;
		&Log("[D][iscsiRecovery] \t[$_]\n");
		if (/$vmhba/){
			$ret = 0;
			last;
		}
	}
	close($h) or &Log( $! ? "[E] close() failed ![" . ($!) ."]\n"
			      : "[W] cmd exit non-zero [" . ($?) . "]\n" );
	&Log(sprintf("[D][iscsiRecovery] ![%d] ?[%d]\n", $!, $?));
	if ($ret == 0){
		return 0;
	} else {
		&Log("[I][iscsiRecovery] no session with [$vmhba] found\n");
	}
	
	$cmd = "esxcli --server $vmk iscsi session add --adapter=$vmhba";
	&Log("[D][iscsiRecovery] executing [$cmd]\n");
	open($h, "$cmd |") or die "[E][iscsiRecovery]\texecution [$cmd] failed [$!]";
	while(<$h>){
		chomp;
		&Log("[D][iscsiRecovery] \t[$_]\n");
	}
	close($h) or &Log( $! ? "[E] close() failed ![" . ($!) ."]\n"
			      : "[W] cmd exit non-zero [" . ($?) . "]\n" );
	$ret = $?;
	&Log(sprintf("[D][iscsiRecovery] ![%d] ?[%d]\n", $!, $?));
	return $ret;	
}

sub Monitor{
	my %vmx;	# path to .vmx file
	my %vmxr;	# path to .vmx file in REMOTE
	my @vmpo;	# VMs which are in power off state
	my @vmiv;	# VMs which are in invalid status

#	# Unregistering invalid VMs on LOCAL node
#	$cmd  = "ssh -i ~/.ssh/id_rsa $vmk \"" . 
#	"for a in \\\$(vim-cmd vmsvc/getallvms 2>&1 | grep invalid | awk \'{print \\\$4}\' | cut -d \\' -f2)\; " .
#			"do echo Invalid VM ID[\\\$a]\; " .
#			"vim-cmd vmsvc/unregister \\\$a 2>&1\;done\"";

	# Finding out registered VMs in iSCSI datastore on LOCAL node
	my $cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd vmsvc/getallvms 2>&1\"";
	&execution($cmd);
	foreach $a (@lines){
		chomp $a;
		#&Log("[D]! \t[$a]\n");
		# TBD
		# Add operation for unregistering inaccessible VMs
		if ($a =~ /^(\d+).*\[$DatastoreName\] (.+\.vmx)/){
			$vmx{$1} = $2;
			&Log("[D] on LOCAL [$vmk] [$1][$2] exists\n");
		}
		elsif ($a =~ /^Skipping invalid VM '(\d.+)'/){
			push(@vmiv, $1);
			&Log("[I] on LOCAL  [$vmk] VM ID [$1] exists as inavalid VM\n");
		}
	}

	# Unregistering invalid VMs on LOCAL node
	foreach (@vmiv){
		$cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd vmsvc/unregister $_ 2>&1\;done\"";
		&execution($cmd);
		foreach $b (@lines){
			chomp $b;
			&Log("[D] \t$b\n");
		}
		&Log("[I] on LOCAL  [$vmk] VM ID [$_] was unregistered\n");
	}

	# Checking Powerstatus of each registered VMs on Local node
	foreach $a (keys %vmx) {
		$cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd vmsvc/power.getstate $a 2>&1\"";
		&execution($cmd);
		foreach (@lines){
			if(/Powered off/){
				&Log("[W] on LOCAL  [$vmk] [$a][$vmx{$a}] was in Powered off status\n");
				push (@vmpo, $a);
			}
		}
	}

	# Finding out registered VMs in iSCSI datastore on REMOTE node
	if ($#vmpo == -1) {return 0;}
	$cmd  = "ssh -i ~/.ssh/id_rsa $vmkr \"vim-cmd vmsvc/getallvms 2>&1\"";
	&execution($cmd);
	foreach(@lines){
		if (/^(\d+).*\[$DatastoreName\] (.+\.vmx)/){
			$vmxr{$1} = $2;
			&Log("[D] on REMOTE [$vmkr] [$1][$2] exists\n");
		}
	}
	# Unregistering LOCAL VM if REMOTE VM is ONLINE
	foreach $a (@vmpo){
		foreach $b (keys %vmxr){
			if ($vmx{$a} eq $vmxr{$b}){
				my $tmp = 0;
				$cmd = "ssh -i ~/.ssh/id_rsa $vmkr \"vim-cmd vmsvc/power.getstate $b 2>&1\"";
				&execution($cmd);
				foreach(@lines){
					chomp;
					&Log("[D] \t$_\n");
					if(/Powered on/){
						$tmp = 1;
					}
				}
				if ($tmp) {
					$cmd = "ssh -i ~/.ssh/id_rsa $vmk \"vim-cmd vmsvc/unregister $a 2>&1\;done\"";
					&execution($cmd);
					foreach(@lines){
						chomp;
						&Log("[D] \t$_\n");
					}
					&Log("[I] on LOCAL  [$vmk] [$a][$vmx{$a}] was unregistered\n");
				} else {
					&Log("[D} on LOCAL  [$vmk] do nothing for [$a][$vmx{$a}]\n");
				}
			}
		}
	}
	return 0;
}

#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	&Log("[D] executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	@lines = <$h>;
	#foreach (@lines) {
	#	chomp;
	#	&Log("[D]\t$_\n");
	#} 
	close($h); 
	&Log(sprintf("[D] result    ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	#&Log(sprintf("[D] executing ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	return $?;
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
