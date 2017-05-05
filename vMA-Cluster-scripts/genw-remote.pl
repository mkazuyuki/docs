#!/usr/bin/perl -w

#
# This monitors online status of CLP, VM (vMA) on remote node.
# - If CLP is offline and VM   is online, then starting CLP.
# - If VM  is offline and ESXi is online, then starting VM.
#
# Script for monitoring the Virtual Machine on standby ESXi
# - This tries to recover the iSCSI session of the ESXi which the vMA (specified as $vma1, $vma2) is running on.
#   It is a countermeasure for that iSCSI Software Adapter on the ESXi cannot recover the iSCSI session after a boot of the ESXi.
# - This tires to clan up invalid VMs and the VMs on the specified Datastore which are registerd on the inventory of standby ESXi.
#   It is a countermeasure for that VM(s) which is in "invalid" or "power off" status left on the standby ESXi inventory after reboot of the ESXi.

 

use strict;
use FindBin;

#-------------------------------------------------------------------------------
# Configuration

# VM name in the ESXi inventory and IP addresses of the VM
my $VMNAME1 = 'vSphere Management Assistant (vMA)01';
my $VMIP1	= "10.0.10.202";

my $VMNAME2 = 'vSphere Management Assistant (vMA)02';
my $VMIP2	= "10.0.10.212";

# IP address of VMKernel port
my $VMK1	= "10.0.12.76";
my $VMK2	= "10.0.12.77";

# VMHBA name of iSCSI Software Adapter on each ESXi
my $VMHBA1	= "vmhba33";
my $VMHBA2	= "vmhba33";

# Datastore Name
my $DatastoreName	= "iSCSI";
#-------------------------------------------------------------------------------

my $LOOPCNT	= 2;	# times
my $SLEEP	= 10;	# seconds
my @lines	= ();
my $noderemote	= "";
my $ret	= 0;

#require($FindBin::Bin . "/vmconf.pl");

my $VMNAME	= "";
my $VMIP	= "";
my $VMK 	= "";
my $VMHBA	= "";
my $tmp = `ip address | grep $VMIP1`;
if ($? == 0) {
	$VMNAME	= $VMNAME2;
	$VMIP = $VMIP2;
	$VMK = $VMK2;
	$VMHBA	= $VMHBA2;
} else {
	$VMNAME	= $VMNAME1;
	$VMIP = $VMIP1;
	$VMK = $VMK1;
	$VMHBA	= $VMHBA1;
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
&iscsiRecovery();

for (my $i = 0; $i < $LOOPCNT; $i++){
	if (!&IsRemoteClpOffline()){
		# Remote ECX is online
		#&Log("[D] remote CLP [$VMIP] is online\n");
		exit 0;
	}
	sleep $SLEEP;
}

&Log("[D] remote CLP [$VMIP] is offline\n");
if (&execution("ping $VMIP -c1")) {
	&Log("[D] remote VM [$VMIP] is offline\n");
	if (&execution("ping $VMK -c1")) {
		&Log("[D] remote ESX [$VMK] is offline\n");
	} else {
		&Log("[D] remote ESX [$VMK] is online, starting VM\n");
		&PowerOnVM();
	}
} else {
	&Log("[D] remote VM [$noderemote:$VMIP] is online, starting CLP\n");
	&execution("clpcl -s -h $noderemote");
}

exit $ret;

#-------------------------------------------------------------------------------
sub PowerOnVM {
	#&Log("[I] Starting [$VMIP][$VMNAME]\n");
	&execution("ssh -i ~/.ssh/id_rsa ${VMK} \"
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
	my $nodelocal	= "";
	my $statremote	= "";

	&execution("clpstat");
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
sub iscsiRecovery{
	my $ret = -1;
	#esxcli --server 192.168.137.52 iscsi session list --adapter=vmhba33
	&execution("esxcli --server $VMK iscsi session list --adapter=$VMHBA");
	foreach (@lines) {
		chomp;
		&Log("[D][iscsiRecovery] \t[$_]\n");
		if (/$VMHBA/){
			$ret = 0;
			last;
		}
	}
	if ($ret == 0){
		return 0;
	} else {
		&Log("[I][iscsiRecovery] no session with [$VMHBA] found\n");
	}
	
	&execution("esxcli --server $VMK iscsi session add --adapter=$VMHBA");
	foreach (@lines) {
		chomp;
		&Log("[D][iscsiRecovery] \t[$_]\n");
	}
	#return $ret;
	return 0;
}

#-------------------------------------------------------------------------------
# Unregistering VMs in the iSCSI datastore on opposite ESXi
# Unregistering invalid VMs on opposite ESXi
sub CleanInventory{
	my $cmd  = "ssh -i ~/.ssh/id_rsa $VMK \"" . 
		"for a in \\\$(vim-cmd vmsvc/getallvms 2>&1 | grep \'\\\[$DatastoreName\\\]\' | awk \'{print \\\$1}\')\; " .
			"do echo stop and unregister VM ID[\\\$a]\; " .
			"vim-cmd vmsvc/power.off \\\$a 2>&1\; vim-cmd vmsvc/unregister \\\$a 2>&1\;done\; " .
		"for a in \\\$(vim-cmd vmsvc/getallvms 2>&1 | grep invalid | awk \'{print \\\$4}\' | cut -d \\' -f2)\; " .
			"do echo Invalid VM ID[\\\$a]\; " .
			"vim-cmd vmsvc/unregister \\\$a 2>&1\;done\"";
	&execution($cmd);
	foreach (@lines) {
		chomp;
		&Log("[D][Moni]or] \t[$_]\n");
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
