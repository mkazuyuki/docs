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
my $vmk = "";
my $vmhba = "";
my $tmp = `ip address | grep $vma1`;
if ($? == 0) {
	$vmk = $vmk1;
	$vmhba = $vmhba1;
} else {
	$vmk = $vmk2;
	$vmhba = $vmhba2;
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
&iscsiRecovery();

my $cmd = "clpstat --local";
my $noderemote = "";
my $nodecurr = "";
&Log("[D] executing [$cmd]\n");
open(my $h, "$cmd |") or die "[E] execution [$cmd] failed [$!]";
while(<$h>){
	chomp;
	if (/^\s{4}(\S+?) /) {
		$noderemote = $1;
	}
	elsif (/<group>/){
		last;
	}
}
while(<$h>){
	if (/current.*: (.*)/) {
		$nodecurr = $1;
		last;
	}
}
close($h) or &Log( $! ? "[E] close() failed ![" . ($!) ."]\n"
		      : "[W] cmd exit non-zero [" . ($?) . "]\n" );
&Log(sprintf("[D] remote[$noderemote] current[$nodecurr] ?[%d] ![%d]\n", $?, $!));
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
	my $cmd  = "ssh -i ~/.ssh/id_rsa $vmk \"" . 
		"for a in \\\$(vim-cmd vmsvc/getallvms 2>&1 | grep \'\\\[$DatastoreName\\\]\' | awk \'{print \\\$1}\')\; " .
			"do echo stop and unregister VM ID[\\\$a]\; " .
			"vim-cmd vmsvc/power.off \\\$a 2>&1\; vim-cmd vmsvc/unregister \\\$a 2>&1\;done\; " .
		"for a in \\\$(vim-cmd vmsvc/getallvms 2>&1 | grep invalid | awk \'{print \\\$4}\' | cut -d \\' -f2)\; " .
			"do echo Invalid VM ID[\\\$a]\; " .
			"vim-cmd vmsvc/unregister \\\$a 2>&1\;done\"";

	&Log("[D][Monitor] executing [$cmd]\n");
	open(my $h, "$cmd |") or die "[E][Monitor]\texecution [$cmd] failed [$!]";
	while(<$h>){
		chomp;
		&Log("[D][Moni]or] \t[$_]\n");
	}
	close($h) or &Log( $! ? "[E][Monitor] close() failed ![" . ($!) ."]\n"
			      : "[W][Monitor] cmd exit non-zero [" . ($?) . "]\n" );
	&Log(sprintf("[D][Monitor] ![%d] ?[%d]\n", $!, $?));
	return 0;
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
