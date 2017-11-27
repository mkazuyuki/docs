#!/usr/bin/perl -w

#
# This monitors online status of CLP, vMA.
# Starting CLP if it is offline and vMA is online.
# Starting vMA if it is offline and ESXi is online.
# 

use strict;
#use FindBin;

#-------------------------------------------------------------------------------
# Configuration

# VM name in the ESXi inventory
my $VMNAME = 'vSphere Management Assistant (vMA)';

# IP address of vMA
my $vma1 = "192.168.137.205";
my $vma2 = "192.168.137.206";

# IP address of VMKernel port
my $vmk1 = "192.168.137.51";
my $vmk2 = "192.168.137.52";
#-------------------------------------------------------------------------------

my $LOOPCNT	= 2;
my $SLEEP	= 10;
my @lines	= ();
my $noderemote	= "";
my $ret	= 0;

#require($FindBin::Bin . "/vmconf.pl");

my $vmk	= "";
my $vma	= "";
my $tmp = `ip address | grep $vma1`;
if ($? == 0) {
	$vma = $vma2;
	$vmk = $vmk2;
} else {
	$vma = $vma1;
	$vmk = $vmk1;
}

for (my $i = 0; $i < $LOOPCNT; $i++){
	if (!&IsRemoteClpOffline()){
		# Remote ECX is online
		#&Log("[D] remote CLP [$vma] is online\n");
		exit 0;
	}
	sleep $SLEEP;
}

&Log("[D] remote CLP [$vma] is offline\n");
if (&execution("ping $vma -c1")) {
	&Log("[D] remote vMA [$vma] is offline\n");
	if (&execution("ping $vmk -c1")) {
		&Log("[D] remote ESX [$vmk] is offline\n");
	} else {
		&Log("[D] remote ESX [$vmk] is online, starting vMA\n");
		&PowerOnVMA();
	}
} else {
	&Log("[D] remote vMA [$noderemote:$vma] is online, starting clp\n");
	&execution("clpcl -s -h $noderemote");
}

exit $ret;

#-------------------------------------------------------------------------------
sub PowerOnVMA {
	#&Log("[I] Starting [$vma][$VMNAME]\n");
	&execution("ssh -i ~/.ssh/id_rsa ${vmk} \"
		vmid=\\\$(vim-cmd vmsvc/getallvms 2>&1 | grep '${VMNAME}' | awk '{print \\\$1}')
		logger -t expresscls \"start VM ID[\\\${vmid}]\" '[${VMNAME}]'
		vim-cmd vmsvc/power.on \\\${vmid} 2>&1\"");

	foreach (@lines) {
		chomp;
		&Log("[D] \t$_\n");
	} 
	return 0;
}

#-------------------------------------------------------------------------------
sub IsRemoteClpOffline {
	my $nodelocal = "";
	my $statremote = "";

	execution("clpstat");
	foreach(@lines){
		chomp;
		if (/^\s{4}(\S+?)\s.*: (.+?)\s/) {
			$noderemote = $1;
			$statremote = $2;
		}
		elsif (/<group>/){
			last;
		}
	}

	#&Log("[D] remote[$noderemote:$statremote]\n");
	if ($statremote eq "Offline") {
		return 1; # TRUE
	} else {
		return 0; # FALSE
	}
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
