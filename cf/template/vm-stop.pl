#!/usr/bin/perl -w
#
# Script for power off the Virtual Machine
#
use strict;
#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
# The path to VM configuration file. This must be absolute UUID-based path.
# like "/vmfs/volumes/<datastore-uuid>/vm1/vm1.vmx";
my $cfg_path = '%%VMX%%';
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
# The interval to check the vm status. (second)
my $interval = 6;
# The miximum count to check the vm status.
my $max_cnt = 50;
#-------------------------------------------------------------------------------
# Global values
my $vmname = "";
my $vmhba = "";
my $vmk = "";
my $cfg = $cfg_path;
$cfg_path =~ s/^.*?([^\/]*\/[^\/]*$)/$1/;
my @lines = ();

my $tmp = `ip address | grep $vma1`;
if ($? == 0) {
	$vmk = $vmk1;
	$vmhba = $vmhba1;
} else {
	$tmp = `ip address | grep $vma2`;
	if ($? == 0) {
		$vmk = $vmk2;
		$vmhba = $vmhba2;
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
# VMname to be output on log.
$vmname = $cfg_path;
$vmname =~ s/^(.*\/)(.*)(\.vmx)/$2/;
&Log("[D] [$vmname][$cfg_path]\n");
if (&IsPoweredOn()){
	if (&PowerOff()){
		&WaitPoweredOffDone();
	}
}
exit &UnRegisterVm();

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
	my $state = shift;
	my $ret = 0;
	my $cmd = "ssh ${vmk} \"
		vmid=\\\$(vim-cmd vmsvc/getallvms 2>&1 | grep '${cfg_path}' | awk '{print \\\$1}')
		logger -t expresscls \"checking pow stat of VM ID[\\\${vmid}]\" '[${cfg_path}]'
		vim-cmd vmsvc/power.getstate \\\${vmid} 2>&1\"";
	&execution($cmd);
	foreach (@lines) {
		if (/^Powered $state$/){
			$ret = 1;
		}
	}
	if ($ret == 1) {
		&Log("[D] [$vmname] at [$vmk]: VM execution state is [$state].\n");
	}else{
		&Log("[E] [$vmname] at [$vmk]: VM execution state is not [$state].\n");
	}
	return $ret;
}
#-------------------------------------------------------------------------------
sub PowerOff{
	my $ret;
	if ( !&IsStorageReady ) {
		$ret = &PowerOffOpMode("off");
	} else {
		$ret = &PowerOffOpMode("shutdown");
		if (!$ret){
			$ret = &PowerOffOpMode("off");
		}
		return $ret;
	}
	return $ret;
}
#-------------------------------------------------------------------------------
sub PowerOffOpMode{
	my $powerop_mode = shift;
	my $ret = 0;
	return 0 if ($powerop_mode !~ /^off|shutdown$/);
	my $cmd = "ssh -i ~/.ssh/id_rsa ${vmk} \"
		vmid=\\\$(vim-cmd vmsvc/getallvms 2>&1 | grep '${cfg_path}' | awk '{print \\\$1}')
		logger -t expresscls \"pow off VM ID[\\\${vmid}]\" '[${cfg_path}]'
		vim-cmd vmsvc/power.${powerop_mode} \\\${vmid} 2>&1\"";
	$ret = &execution($cmd);
	if ($ret == 0) {
		&Log("[I] [$vmname] at [$vmk]: Stopped. ($powerop_mode)\n");
		$ret = 1;
	}else{
		&Log("[E] [$vmname] at [$vmk]: Could not stop ($powerop_mode)\n");
		foreach (@lines){
			if ( /vim.fault.QuestionPending/ ) {
				# Countermeasure for when iSCSI Cluster gets failover while
				# VM is running and become to have vmdk which is not locked.
				# The VM start to shutdown and get QuestionPending status.
				&ResolveVmStuck;
			}
		}
		$ret = 0;
	}

	return $ret;
}
#-------------------------------------------------------------------------------
sub WaitPoweredOffDone{
	my $cmd = "ssh ${vmk} \"vim-cmd vmsvc/getallvms 2>&1 | grep '${cfg_path}'\"";
	my $ret = &execution($cmd);
	if ($ret != 0) {
		&Log("[I] [$vmname] at [$vmk] not exist in inventory.\n");
		return 1;
	}

	for (my $i = 0; $i < $max_cnt; $i++){
		if ( ! &IsStorageReady ) {
			&PowerOffOpMode("off");
			return 1;
		}
		if (&IsEqualState($state{"VM_EXECUTION_STATE_OFF"})){
			&Log("[I] [$vmname] at [$vmk]: Powered off done. times cnt = [$i]\n");
			return 1;
		}
		&Log("[I] [$vmname] at [$vmk]: Waiting peowered off. count=[$i]\n");
		sleep $interval;
	}
	&Log("[E] [$vmname] at [$vmk]: Not powered off done. count=[$max_cnt] (wait count max)\n");
	return 0;
}
#-------------------------------------------------------------------------------
sub UnRegisterVm{
	my $ret = 0;
	my $flag = 0;
	my $cmd = "ssh ${vmk} \"vim-cmd vmsvc/getallvms 2>&1 | grep '${cfg_path}'\"";
	&execution($cmd);

	foreach(@lines){
		if (/$cfg_path/) {
			&Log("[I] [$vmname] at [$vmk] exists, unregistering.\n");
			$flag = 1;
		}
	}
	if ($flag == 0){
		&Log("[I] [$vmname] at [$vmk] already unregistered.\n");
		return 0;
	}

	$cmd = "ssh ${vmk} \"
		vmid=\\\$(vim-cmd vmsvc/getallvms 2>&1 | grep '${cfg_path}' | awk '{print \\\$1}')
		logger -t expresscls \"unregistering VM ID[\\\${vmid}]\" '[${cfg_path}]'
		vim-cmd vmsvc/unregister \\\${vmid} 2>&1\"";
	&execution($cmd);

	$cmd = "ssh ${vmk} \"vim-cmd vmsvc/getallvms 2>&1 | grep '${cfg_path}'\"";
	&execution($cmd);
	foreach(@lines){
		if (/$cfg_path/) {
			&Log("[I] [$vmname] at [$vmk] exists, failed.\n");
			return 1;
		}
	}
	&Log("[I] [$vmname] at [$vmk] unregistered.\n");
	return 0;
}
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

sub ResolveVmStuck{
	my $vmop = "answer";
	my $ret = 0;
	my $opn_ret;
	my $cmd = "/usr/bin/vmware-cmd --server $vmk $cfg $vmop";
	$opn_ret = open(my $fh, "| ". $cmd);
	if (!$opn_ret){
		&Log("[E] [$vmname] at [$vmk]: [$cmd] could not be executed.\n");
		return 0;
	}
	# Answering "0) OK".
	print($fh "0\n");
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
sub Log{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
	print "$date $_[0]";
	return 0;
}
