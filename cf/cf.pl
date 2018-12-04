#!/usr/bin/perl -w

#
# This script creates ECX configuration files (clp.conf and scripts)
# and configurs password free access from iSCSI and vMA hosts to ESXi hosts
# 
# Prerequisite package
#
#	VMware-vSphere-CLI-6.0.0-3561779.exe
#		https://my.vmware.com/jp/web/vmware/details?productId=491&downloadGroup=VCLI60U2
#
#	plink.exe , pscp.exe
#		https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
#			https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe
#			https://the.earth.li/~sgtatham/putty/latest/w64/pscp.exe

use strict;
use Cwd;

my $vmcmd_dir;
if ( defined $ENV{'ProgramFiles(x86)'} ) {
	$vmcmd_dir = $ENV{'ProgramFiles(x86)'};
} else {
	$vmcmd_dir = $ENV{'ProgramFiles'};
}
$vmcmd_dir .= '\VMware\VMware vSphere CLI\bin';
my $vmcmd = 'perl vmware-cmd.pl';

my $CFG_DIR	= "conf";
my $CFG_FILE	= $CFG_DIR . "/clp.conf";
my $CFG_CRED	= "credstore_.pl";
my $SCRIPT_DIR	= "script";
my $TMPL_DIR	= "template";
my $TMPL_CONF	= $TMPL_DIR . "/clp.conf";
my $TMPL_START	= $TMPL_DIR . "/vm-start.pl";
my $TMPL_STOP	= $TMPL_DIR . "/vm-stop.pl";
my $TMPL_MON	= $TMPL_DIR . "/genw-vm.pl";
my $TMPL_CRED	= $TMPL_DIR . "/credstore.pl";

# Development environment
my @esxi_ip	= ('172.31.255.2', '172.31.255.3');		# ESXi IP address
my @esxi_pw	= ('NEC123nec!', 'NEC123nec!');			# ESXi root password
my @vma_ip	= ('172.31.255.6', '172.31.255.7');		# vMA IP address
my @vma_pw	= ('NEC123nec!', 'NEC123nec!');			# vMA vi-admin password
my @iscsi_ip	= ('172.31.255.11', '172.31.255.12');		# iSCSI IP address
my @iscsi_pw	= ('NEC123nec!', 'NEC123nec!');			# iSCSI root password
my $dsname	= "iSCSI";					# iSCSI Datastore
my $vsw		= "vSwitch0";					# vSwitch for UCVM

#my $i = 1;
#&execution(".\\plink.exe -l vi-admin -pw $vma_pw[$i]   $vma_ip[$i]   \"echo $vma_pw[$i] | sudo -S sh -c \\\"cp /root/.ssh/id_rsa.pub /tmp\\\"\"");
#&execution(".\\pscp.exe  -l vi-admin -pw $vma_pw[$i]   $vma_ip[$i]:/tmp/id_rsa.pub .\\id_rsa_vma_$i.pub");
#&execution(".\\pscp.exe  -l root     -pw $iscsi_pw[$i] .\\id_rsa_vma_$i.pub $iscsi_ip[$i]:/tmp");
#&execution(".\\plink.exe -l root     -pw $iscsi_pw[$i] $iscsi_ip[$i] \"a=`cat /tmp/id_rsa_vma_$i.pub`; grep \\\"\$a\\\" ~/.ssh/authorized_keys\"");
#if ($? != 0) {
#	&execution(".\\plink.exe -l root -pw $iscsi_pw[$i] $iscsi_ip[$i] \"cat /tmp/id_rsa_vma_$i.pub >> ~/.ssh/authorized_keys\"");
#}
#&execution(".\\plink.exe -l root     -pw $iscsi_pw[$i] $iscsi_ip[$i] \"rm /tmp/id_rsa_vma_$i.pub\"");
#unlink ( ".\\id_rsa_vma_$i.pub" ) or die;
#exit;

## Initial environment
#my @esxi_ip	= ('0.0.0.0', '0.0.0.0');	# ESXi IP address
#my @esxi_pw	= ('(none)', '(none)'); 	# ESXi root password
#my @vma_hn	= ('(none)', '(none)'); 	# vMA hostname
#my @vma_ip	= ('0.0.0.0', '0.0.0.0');	# vMA IP address
#my @vma_pw	= ('(none)', '(none)');		# vMA vi-admin password
#my $dsname	= "iSCSI";			# iSCSI Datastore
#my $vmhba	= "vmhba33";			# iSCSI Software Adapter

my @wwn 	= ('iqn.1998-01.com.vmware:1', 'iqn.1998-01.com.vmware:2');	# Pre-defined iSCSI WWN to be set to ESXi
my @vmhba	= ('', '');							# iSCSI Software Adapter
my @vma_hn	= ('', '');							# vMA hostname
my @vma_dn	= ('', '');							# vMA Display Name

my @vmx = ();		# Array of Hash of VMs for an ESXi
my @menu_vMA;
my $ret = "";
my @outs = ();

open(IN, $TMPL_CONF);
my @lines = <IN>;
close(IN);

while ( 1 ) {
	if ( ! &select ( &menu ) ) {exit}
}

exit;

##
# subroutines
#

#
# Changing clp.conf contents for adding new VM group resource
#-------
sub AddNode {
	my $esxidx = shift;
	my $vmname = shift;
	my $i = 0;
	my $gid = 0;
	my $fop = "";

	#print "[D] esxidx[$esxidx] vmname[$vmname]\n";

	for($i = $#lines; $i > 0; $i--){
		if($lines[$i] =~ /<gid>(.*)<\/gid>/){
			$gid = $1 + 1;
			last;
		}
	}

	#
	# Failover Policy
	#
	if ($esxidx == 1) {
		$fop =	"		<policy name=\"$vma_hn[1]\"><order>0</order></policy>\n".
			"		<policy name=\"$vma_hn[0]\"><order>1</order></policy>\n";
	}

	#
	# Group
	#
	my @ins = (
		"	<group name=\"failover-$vmname\">\n",
		"		<comment> <\/comment>\n",
		"		<resource name=\"exec\@exec-$vmname\"/>\n",
		"		<gid>$gid</gid>\n",
		$fop,
		"	</group>\n"
	);
	splice(@lines, $#lines, 0, @ins);

	#
	# Resource
	#
	@ins = (
		"		<exec name=\"exec-$vmname\">",
		"			<comment> </comment>",
		"			<parameters>",
		"				<act><path>start.sh</path></act>",
		"				<deact><path>stop.sh</path></deact>",
		"				<userlog>/opt/nec/clusterpro/log/exec-$vmname.log</userlog>",
		"				<logrotate><use>1</use></logrotate>",
		"			</parameters>",
		"			<act><retry>2</retry></act>\n",
		"			<deact>\n",
		"				<action>5</action>\n",
		"				<retry>1</retry>\n",
		"			</deact>\n",
		"		</exec>\n"
	);
	for($i = $#lines; $i > 0; $i--){
		if($lines[$i] =~ /<\/resource>/){
			last;
		}
	}
	splice(@lines, $i, 0, @ins);

	#
	# Monitor
	#
	@ins = (
		"	<genw name=\"genw-$vmname\">\n",
		"		<comment> </comment>\n",
		"		<target>exec-$vmname</target>\n",		##
		"		<parameters>\n",
		"			<path>genw.sh</path>\n",
		"			<userlog>/opt/nec/clusterpro/log/genw-$vmname.log</userlog>\n",		##
		"			<logrotate>\n",
		"				<use>1</use>\n",
		"			</logrotate>\n",
		"		</parameters>\n",
		"		<polling>\n",
		"			<timing>1</timing>\n",
		"			<reconfirmation>1</reconfirmation>\n",
		"		</polling>\n",
		"		<relation>\n",
		"			<name>failover-$vmname</name>\n",	##
		"			<type>grp</type>\n",
		"		</relation>\n",
		"		<emergency>\n",
		"			<threshold>\n",
		"				<restart>0</restart>\n",
		"			</threshold>\n",
		"		</emergency>\n",
		"	</genw>\n"
	);
	for($i = $#lines; $i > 0; $i--){
		if (($lines[$i] =~ /<\/genw>/) || ($lines[$i] =~ /<types name=\"genw\"\/>/)){
			last;
		}
	}
	splice(@lines, $i +1, 0, @ins);

	#
	# Object number
	#
	for($i = $#lines; $i > 0; $i--){
		if($lines[$i] =~ /<objectnumber>(.*)<\/objectnumber>/){
			$lines[$i] = "<objectnumber>" .  ($1 + 2) . "</objectnumber>";
			last;
		}
	}
}

sub DelNode {
	my $esxidx = shift;
	my $vmname = shift;
	my $i = 0;
	my $j = 0;
	my $gid = 0;

	print "[D] deleting [$vmx[$esxidx]{$vmname}]\n";
	delete($vmx[$esxidx]{$vmname});

	#
	# Group
	#
	for($i = 0; $i < $#lines; $i++){
		if ($lines[$i] =~ /<group name=\"failover-$vmname\">/) {
			last;
		}
	}
	for($j = $i + 1; $j < $#lines; $j++){
		if ($lines[$j] =~ /<\/group>/) {
			last;
		}
	}
	my @deleted = splice(@lines, $i, $j-$i+1);
	#print "----\n[D]" . join ("[D]", @deleted);

	#
	# Resource
	#
	for($i = 0; $i < $#lines; $i++){
		if ($lines[$i] =~ /<exec name=\"exec-$vmname\">/) {
			last;
		}
	}
	for($j = $i + 1; $j < $#lines; $j++){
		if ($lines[$j] =~ /<\/exec>/) {
			last;
		}
	}
	@deleted = splice(@lines, $i, $j-$i+1);
	#print "----\n[D]" . join ("[D]", @deleted);

	#
	# Monitor
	#
	for($i = 0; $i < $#lines; $i++){
		if ($lines[$i] =~ /<genw name=\"genw-$vmname\">/) {
			last;
		}
	}
	for($j = $i + 1; $j < $#lines; $j++){
		if ($lines[$j] =~ /<\/genw>/) {
			last;
		}
	}
	@deleted = splice(@lines, $i, $j-$i+1);
	#print "----\n[D]" . join ("[D]", @deleted);

	#
	# GID
	# Object Number
	#
	foreach (@lines) {
		if (/<gid>(.*)<\/gid>/) {
			s/$1/$gid/;
			$gid++;
		}
		if(/<objectnumber>(.*)<\/objectnumber>/){
			my $objnum = $1 - 2;
			s/$1/$objnum/;
		}
	}
}

#
# Get Display Name of vMA hosts
# 	Setting up @vma_dn
#
sub getvMADisplayName{
	my @dirstack = ();
	push @dirstack, getcwd;
	chdir $vmcmd_dir;

	# Finding vMA <Display Name> from vMA <IP>\n";
	for (my $i = 0; $i < 2; $i++) {
		my $found = 0;
		my $thumbprint = "";
		my $cmd1 = $vmcmd . ' -U root -P ' . $esxi_pw[$i] . ' -H ' . $esxi_ip[$i];

		print "[D] ----------\n";
		print "[D] Getting thumbprint of ESXi host\n";
		print "[D] ----------\n";
		&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " vm process list");
		foreach ( @outs ) {
			if ( /thumbprint: (.+?) / ) {
				$thumbprint = $1;
				last;
			}
		}

		print "[D] ----------\n";
		print "[D] Getting VM <Display Name> and <Config File>\n";
		print "[D] ----------\n";
		&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " -d $thumbprint vm process list");
		my %cf = ();
		for (my $n = 0; $n <= $#outs; $n++) {
			if ( $outs[$n] =~ /Config File: (.+)/ ) {
				$cf{$outs[ $n - 6 ]} = $1;
				# print "[D] ! [$outs[$n - 6]][" . $cf{$outs[ $n - 6 ]}. "]\n";
			}
		}

		print "[D] ----------\n";
		print "[D] Finding vMA <Display Name> by getting IP of <Config File>\n";
		print "[D] ----------\n";
		foreach my $dn (keys %cf) {
			&execution ( $cmd1 . " \"" . $cf{$dn} . "\" getguestinfo ip" );
			if ( $outs[0] =~ /$vma_ip[$i]/ ) {
				$found = 1;
				$vma_dn[$i] = $dn;
				print "[D] ----------\n";
				print "[D] Found vMA Display Name [$vma_dn[$i]] for ESXi #[$i]\n";
				print "[D] ----------\n";
				last;
			}
		}

		if ($found == 0) {
			die "[E] No vMA found\n";
		}
	}
	chdir pop @dirstack;
}

sub setIQN {
	my @dirstack = ();
	push @dirstack, getcwd;
	chdir $vmcmd_dir;

	for (my $i = 0; $i < 2; $i++) {
		my $thumbprint = "";

		# Getting thumbprint of ESXi host
		&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " vm process list");
		foreach ( @outs ) {
			if ( /thumbprint: (.+?) / ) {
				$thumbprint = $1;
				last;
			}
		}
		&Log("[I] ----------\n");
		&Log("[I] thumbprint of ESXi#" . ($i +1) . " ($esxi_ip[$i]) = [$thumbprint]\n");
		&Log("[I] ----------\n");

		# Getting vmhba
		&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " -d $thumbprint iscsi adapter list");
		foreach ( @outs ) {
			if ( /^vmhba[\S]+/ ) {
				$vmhba[$i] = $&;
			}
		}
		&Log("[I] ----------\n");
		&Log("[I] iSCSI Sofware Adapter HBA#" . ($i +1) . " = [" . $vmhba[$i] . "]\n");
		&Log("[I] ----------\n");

		# Checking WWN before setting it
		&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " -d $thumbprint iscsi adapter get -A $vmhba[$i]");
		foreach ( @outs ) {
			if ( /^   Name: (.+)/ ) {
				&Log("[I] ----------\n");
				&Log("[I] Before setting WWN#" . ($i +1) . " = [$1]\n");
				&Log("[I] ----------\n");
			}
		}

		# Setting WWN
		&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " -d $thumbprint iscsi adapter set -A $vmhba[$i] -n $wwn[$i]");

		# Checking WWN after setting it
		&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " -d $thumbprint iscsi adapter get -A $vmhba[$i]");
		foreach ( @outs ) {
			if ( /^   Name: (.+)/ ) {
				&Log("[I] ----------\n");
				&Log("[I] After setting  WWN#" . ($i +1) . " = [$1]\n");
				&Log("[I] ----------\n");
				# $wwn[$i] = $1;
			}
		}
	}

	chdir pop @dirstack;

}


#
# Setup before.local and after.local on vMA hosts
#
sub putInitScripts {
	my @locals = ("before.local", "after.local");
	for (my $n = 0; $n < 2; $n++) {
		foreach my $file (@locals) {
			open(IN, "$TMPL_DIR/$file") or die;
			open(OUT,">  $file") or die;
			#binmode(IN);
			binmode(OUT);
			while (<IN>) {
				if (/%%VMK%%/)		{ s/$&/$esxi_ip[$n]/;}
				if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
				print OUT;
			}
			close(OUT);
			close(IN);
			&execution(".\\pscp.exe -l vi-admin -pw $vma_pw[$n] $file $vma_ip[$n]:/tmp");
			unlink ( "$file" ) or die;
		}

		my $file = "vma-init-files.sh";
		open(IN, "$SCRIPT_DIR/$file") or die;
		open(OUT,">  $file") or die;
		while (<IN>) {
			if (/%%VMAPW%%/)	{ s/$&/$vma_pw[$n]/;}
			print OUT;
		}
		close(OUT);
		close(IN);
		&execution(".\\plink.exe -l vi-admin -pw $vma_pw[$n] $vma_ip[$n] -m $file");
		unlink ( "$file" ) or die;
	}
}

sub Save {
	print "[I] Check ESXi, iSCSI nodes connectable";
	for (my $i = 0; $i < 2; $i++) {
		if (&execution(".\\plink.exe -l root -pw $esxi_pw[$i] $esxi_ip[$i] hostname")) {
			&Log("[E] failed to access ESXi#" . ($i+1) .". Check IP or password.\n");
			return -1;
		}
		if (&execution(".\\plink.exe -l root -pw $iscsi_pw[$i] $iscsi_ip[$i] hostname")) {
			&Log("[E] failed to access iscsi#" . ($i+1) .". Check IP or password.\n");
			return -1;
		}
		# checking vMA node connectivity was done at addVM()
	}

	# Setup before.local and after.local on vMA hosts
	&putInitScripts;

	# Setup iSCSI Initiator IQN
	&setIQN;

	# Setup Authentication

	# script for credstoreadmin.pl on vMA
	open(IN, "$SCRIPT_DIR/credstore.pl") or die;
	open(OUT,"> $CFG_CRED") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;

		#if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
		#if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
		#if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
		if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
		if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
		#if (/%%VMA1%%/)	{ s/$&/$vma_ip[0]/;}
		#if (/%%VMA2%%/)	{ s/$&/$vma_ip[1]/;}
		if (/%%VMKPW1%%/)	{ s/$&/$esxi_pw[0]/;}
		if (/%%VMKPW2%%/)	{ s/$&/$esxi_pw[1]/;}

		#print "[D>] $_";
		print OUT;
	}
	close(OUT);
	close(IN);

	# execution file for credstore.pl copied on vMA
	for (my $i = 0; $i < 2; $i++) {
		open(IN, "$SCRIPT_DIR/credstore.sh") or die;
		open(OUT,"> credstore_$i.sh") or die;
		while (<IN>) {
			if (/%%VMAPW%%/)	{ s/$&/$vma_pw[$i]/;}
			if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
			if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
			print OUT;
		}
		close(OUT);
		close(IN);
	}

	# execution file for ssh-keyscan on iscsi
	open(IN, "$SCRIPT_DIR/ssh-keyscan.sh") or die;
	open(OUT,"> ssh-keyscan.sh") or die;
	while (<IN>) {
		if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
		if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
		print OUT;
	}
	close(OUT);
	close(IN);

	for (my $i = 0; $i<2; $i++){
		# Put credstore controlling script to vMA
		&execution(".\\pscp.exe -l vi-admin -pw $vma_pw[$i] $CFG_CRED $vma_ip[$i]:/tmp");

		# Access to vMA and execute credstore_admin.pl
		&execution(".\\plink.exe -l vi-admin -pw $vma_pw[$i] $vma_ip[$i] -m credstore_$i.sh");
		if ($?) {
			print "\n[E] failed to execute credstore_admin.pl\n";
			return -1
		}
		# Configure id_rsa.pub and known_hosts file on iscsi
		&execution(".\\plink.exe -l root -pw $iscsi_pw[$i] $iscsi_ip[$i] -m ssh-keyscan.sh");

		# Get ssh public key from vMA, iSCSI
		&execution(".\\plink.exe -l vi-admin -pw $vma_pw[$i] $vma_ip[$i] \"echo $vma_pw[$i] | sudo -S sh -c \\\"cp /root/.ssh/id_rsa.pub /tmp\\\"\"");
		&execution(".\\pscp.exe -l vi-admin -pw $vma_pw[$i] $vma_ip[$i]:/tmp/id_rsa.pub .\\id_rsa_vma_$i.pub");
		&execution(".\\plink.exe -l vi-admin -pw $vma_pw[$i] $vma_ip[$i] \"echo $vma_pw[$i] | sudo -S sh -c \\\"rm /tmp/id_rsa.pub\\\"\"");
		&execution(".\\pscp.exe -l root -pw $iscsi_pw[$i] $iscsi_ip[$i]:/root/.ssh/id_rsa.pub .\\id_rsa_iscsi_$i.pub");

		# Put ssh public key to ESXi
		&execution(".\\pscp.exe -l root -pw $esxi_pw[0] .\\id_rsa_vma_$i.pub $esxi_ip[0]:/tmp");
		&execution(".\\pscp.exe -l root -pw $esxi_pw[1] .\\id_rsa_vma_$i.pub $esxi_ip[1]:/tmp");
		&execution(".\\pscp.exe -l root -pw $esxi_pw[0] .\\id_rsa_iscsi_$i.pub $esxi_ip[0]:/tmp");
		&execution(".\\pscp.exe -l root -pw $esxi_pw[1] .\\id_rsa_iscsi_$i.pub $esxi_ip[1]:/tmp");

		# Put vMA ssh public key to iSCSI and make /root/.ssh/authorized_keys for vMA
		&execution(".\\pscp.exe -l root -pw $iscsi_pw[$i] .\\id_rsa_vma_$i.pub $iscsi_ip[$i]:/tmp");
		&execution(".\\plink.exe -l root -pw $iscsi_pw[$i] $iscsi_ip[$i] \"a=`cat /tmp/id_rsa_vma_$i.pub`; grep \\\"\$a\\\" ~/.ssh/authorized_keys\"");
		if ($?) {
			# create entry for vMA in authorized_keys in iSCSI when authorized_keys not exists or it does not have the entry for vMA node.
			&execution(".\\plink.exe -l root -pw $iscsi_pw[$i] $iscsi_ip[$i] \"cat /tmp/id_rsa_vma_$i.pub >> ~/.ssh/authorized_keys\"");
		}
		&execution(".\\plink.exe -l root -pw $iscsi_pw[$i] $iscsi_ip[$i] \"rm /tmp/id_rsa_vma_$i.pub\"");

		&execution("del credstore_$i.sh id_rsa_vma_$i.pub id_rsa_iscsi_$i.pub");
	}

	for (my $i = 0; $i<2; $i++){
		# Access to ESXi, make /etc/ssh/keys-root/authorized_keys, and set ATS Heartbeat disable.
		&execution(".\\plink.exe -l root -pw $esxi_pw[$i] $esxi_ip[$i] -m $SCRIPT_DIR/sshmk.sh");
	}

	&execution("del $CFG_CRED ssh-keyscan.sh");

	#
	# Making directry for Group and Monitor resource
	#
	my @DIR = ();
	push @DIR, "$CFG_DIR";
	push @DIR, "$CFG_DIR/scripts";
	push @DIR, "$CFG_DIR/scripts/monitor.s";
	foreach (@lines){
		if (/<group name=\"failover-(.*)\">/) {
			#print "[D] $1\n";
			push @DIR, "$CFG_DIR/scripts/failover-$1";
			push @DIR, "$CFG_DIR/scripts/failover-$1/exec-$1";
			push @DIR, "$CFG_DIR/scripts/monitor.s/genw-$1";
		}
	}
	push @DIR, "$CFG_DIR/scripts/monitor.s/genw-remote-node";
	push @DIR, "$CFG_DIR/scripts/monitor.s/genw-esxi-inventory";
	push @DIR, "$CFG_DIR/scripts/monitor.s/genw-nic-link";
	foreach (@DIR) {
		mkdir "$_" if (!-d "$_");
	}

	#
	# Saving clp.conf
	#
	open(OUT, "> $CFG_FILE");
	foreach (@lines){
		#print "[D<] $_" if /%%/;
		if (/%%VMA1%%/)	{ s/$&/$vma_hn[0]/;}
		if (/%%VMA2%%/)	{ s/$&/$vma_hn[1]/;}
		if (/%%VMA1IP%%/)	{ s/$&/$vma_ip[0]/;}
		if (/%%VMA2IP%%/)	{ s/$&/$vma_ip[1]/;}
		#print "[D ] $_";
		print OUT;
	}
	#print OUT @lines;
	close(OUT);

	#
	# Creating start.sh stop.sh genw.sh
	#
	for my $i (0 .. $#vmx) {
		foreach my $vm (keys %{$vmx[$i]}) {
			open(IN, "$TMPL_START") or die;
			open(OUT,"> $CFG_DIR/scripts/failover-$vm/exec-$vm/start.sh") or die;
			while (<IN>) {
				#print "[D<] $_" if /%%/;

				if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
				if (/%%VMHBA1%%/)	{ s/$&/$vmhba[0]/;}
				if (/%%VMHBA2%%/)	{ s/$&/$vmhba[1]/;}
				if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
				if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
				if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
				if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
				if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}

				#print "[D ] $_";
				print OUT;
			}
			close(OUT);
			close(IN);

			open(IN, "$TMPL_STOP") or die;
			open(OUT,"> $CFG_DIR/scripts/failover-$vm/exec-$vm/stop.sh") or die;
			while (<IN>) {
				#print "[D<] $_" if /%%/;

				if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
				if (/%%VMHBA1%%/)	{ s/$&/$vmhba[0]/;}
				if (/%%VMHBA2%%/)	{ s/$&/$vmhba[1]/;}
				if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
				if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
				if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
				if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
				if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}

				#print "[D ] $_";
				print OUT;
			}
			close(OUT);
			close(IN);

			open(IN, "$TMPL_MON") or die;
			open(OUT,"> $CFG_DIR/scripts/monitor.s/genw-$vm/genw.sh") or die;
			while (<IN>) {
				#print "[D<] $_" if /%%/;

				if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
				#if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
				#if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
				if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
				if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
				if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
				if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}

				#print "[D ] $_";
				print OUT;
			}
			close(OUT);
			close(IN);
		}
	}
	open(IN, "$TMPL_DIR/genw-esxi-inventory.pl") or die;
	open(OUT,"> $CFG_DIR/scripts/monitor.s/genw-esxi-inventory/genw.sh") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;
		#if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
		if (/%%VMHBA1%%/)	{ s/$&/$vmhba[0]/;}
		if (/%%VMHBA2%%/)	{ s/$&/$vmhba[1]/;}
		if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
		if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
		if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
		if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
		if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}
		#print "[D ] $_";
		print OUT;
	}
	close(OUT);
	close(IN);

	&getvMADisplayName;

	open(IN, "$TMPL_DIR/genw-remote-node.pl") or die;
	open(OUT,"> $CFG_DIR/scripts/monitor.s/genw-remote-node/genw.sh") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;
		#if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
		#if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
		#if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
		if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
		if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
		if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
		if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}
		if (/%%VMADN1%%/)	{ s/$&/$vma_dn[0]/;}
		if (/%%VMADN2%%/)	{ s/$&/$vma_dn[1]/;}
		#print "[D ] $_";
		print OUT;
	}
	close(OUT);
	close(IN);

	open(IN, "$TMPL_DIR/genw-nic-link.pl") or die;
	open(OUT,"> $CFG_DIR/scripts/monitor.s/genw-nic-link/genw.sh") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;
		#if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
		#if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
		#if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
		if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
		if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
		if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
		if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}
		if (/%%VSWITCH%%/)	{ s/$&/$vsw/;}
		#print "[D ] $_";
		print OUT;
	}
	close(OUT);
	close(IN);

	open(IN, "$TMPL_DIR/genw-nic-link-preaction.sh") or die;
	open(OUT,"> $CFG_DIR/scripts/monitor.s/genw-nic-link/preaction.sh") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;
		#if (/%%VMX%%/)		{ s/$&/$vmx[$i]{$vm}/;}
		#if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
		#if (/%%DATASTORE%%/)	{ s/$&/$dsname/;}
		#if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;}
		#if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;}
		if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;}
		if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;}
		if (/%%ISCSI1%%/)	{ s/$&/$iscsi_ip[0]/;}
		if (/%%ISCSI2%%/)	{ s/$&/$iscsi_ip[1]/;}
		#if (/%%VSWITCH%%/)	{ s/$&/$vsw/;}
		#print "[D ] $_";
		print OUT;
	}
	close(OUT);
	close(IN);

	#
	# Applying the configuration
	#
	print "[I] ----------\n";
	print "[I] Applying the configuration to vMA cluster\n";
	print "[I] ----------\n";
	&execution(".\\pscp.exe -l vi-admin -pw $vma_pw[0] -r .\\conf $vma_ip[0]:/tmp");
	&execution(".\\plink.exe -l vi-admin -pw $vma_pw[0] $vma_ip[0] \"echo $vma_pw[0] | sudo -S sh -c \'clpcl -t -a\'\"");
	&execution(".\\plink.exe -l vi-admin -pw $vma_pw[0] $vma_ip[0] \"echo $vma_pw[0] | sudo -S sh -c \'clpcfctrl --push -w -x /tmp/conf\'\"");
	&execution(".\\plink.exe -l vi-admin -pw $vma_pw[0] $vma_ip[0] \"echo $vma_pw[0] | sudo -S sh -c \'clpcl -s -a\'\"");

	return 0;
}

sub menu {
	@menu_vMA = (
		'save and exit',
		'set ESXi#1 IP            : ' . $esxi_ip[0],
		'set ESXi#2 IP            : ' . $esxi_ip[1],
		'set ESXi#1 root password : ' . $esxi_pw[0],
		'set ESXi#2 root password : ' . $esxi_pw[1],
		'set vMA#1 IP             : ' . $vma_ip[0],
		'set vMA#2 IP             : ' . $vma_ip[1],
		'set vMA#1 vi-admin passwd: ' . $vma_pw[0],
		'set vMA#2 vi-admin passwd: ' . $vma_pw[1],
		'set iSCSI#1 IP           : ' . $iscsi_ip[0],
		'set iSCSI#2 IP           : ' . $iscsi_ip[1],
		'set iSCSI#1 root password: ' . $iscsi_pw[0],
		'set iSCSI#2 root password: ' . $iscsi_pw[1],
		'set iSCSI Datastore name : ' . $dsname,
		'set vSwitch name         : ' . $vsw,
		'add VM',
		'del VM',
		'show VM'
	);
	my $i = 0;
	print "\n--------\n";
	foreach (@menu_vMA) {
		print "[" . ($i++) . "] $_\n";  
	}
	print "\n(0.." . ($i - 1) . ") > ";

	$ret = <STDIN>;
	chomp $ret;
	return $ret;
}

sub select {
	my $i = shift;
	if ($i !~ /^\d+$/){
		print "invalid (should be numeric)\n";
		return -1;
	}
	elsif ( $menu_vMA[$i] =~ /save and exit/ ) {
		&Save;
		print "\nThe configuration has applied (the same has saved in the \"conf\" directry).\nBye.\n";
		return 0;
	}
	elsif ( $menu_vMA[$i] =~ /set ESXi#([1..2]) IP/ ) {
		&setESXiIP($1);
	}
	elsif ( $menu_vMA[$i] =~ /set ESXi#([1,2]) root password/ ) {
		&setESXiPwd($1);
	}
	elsif ( $menu_vMA[$i] =~ /set vMA#([1,2]) IP/ ) {
		&setvMAIP($1);
	}
	elsif ( $menu_vMA[$i] =~ /set vMA#([1..2]) vi-admin passwd/ ) {
		&setvMAPwd($1);
	}
	elsif ( $menu_vMA[$i] =~ /set iSCSI#([1,2]) IP/ ) {
		&setiSCSIIP($1);
	}
	elsif ( $menu_vMA[$i] =~ /set iSCSI#([1..2]) root password/ ) {
		&setiSCSIPwd($1);
	}
	elsif ( $menu_vMA[$i] =~ /set iSCSI Datastore name/ ) {
		&setDatastoreName;
	}
	elsif ( $menu_vMA[$i] =~ /set vSwitch name/ ) {
		&setvSwitch($1);
	}
	elsif ( $menu_vMA[$i] =~ /add VM/ ) {
		&addVM;
	}
	elsif ( $menu_vMA[$i] =~ /del VM/ ) {
		&delVM;
	}
	elsif ( $menu_vMA[$i] =~ /show VM/ ) {
		&showVM;
	}
	else {
		print "[$i] Invalid.\n";
	}
	return $i;
}

sub setESXiIP {
	my $i = $_[0] - 1;
	print "[" . $esxi_ip[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$esxi_ip[$i] = $ret;
	}
}

sub setESXiPwd{
	my $i = $_[0] - 1;
	print "[" . $esxi_pw[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$esxi_pw[$i] = $ret;
	}
}

sub setvMAIP{
	my $i = $_[0] - 1;
	print "[" . $vma_ip[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$vma_ip[$i] = $ret;
	}
}

sub setvMAPwd{
	my $i = $_[0] - 1;
	print "[" . $vma_pw[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$vma_pw[$i] = $ret;
	}
}

sub setiSCSIIP{
	my $i = $_[0] - 1;
	print "[" . $iscsi_ip[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$iscsi_ip[$i] = $ret;
	}
}

sub setiSCSIPwd{
	my $i = $_[0] - 1;
	print "[" . $iscsi_pw[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$iscsi_pw[$i] = $ret;
	}
}

sub setDatastoreName{
	print "[" . $dsname . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$dsname = $ret;
	}
}

sub setvSwitch {
	print "[" . $vsw . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$vsw = $ret;
	}
}

sub addVM {

	# Check vMA nodes connectable and get hostname
	if (( $vma_hn[0] eq '' ) || ( $vma_hn[1] eq '' )) {
		print "\n[I] Getting hostname of vMA\n";
		print "-----------\n";
		for (my $i = 0; $i < 2; $i++) {
			if (&execution(".\\plink.exe -l vi-admin -pw $vma_pw[$i] $vma_ip[$i] hostname")) {
				&Log("[E] failed to access vMA#" . ($i+1) .". Check IP or password.\n");
				return -1;
			} else {
				$vma_hn[$i] = shift @outs;
				&Log("[I] vMA#" . ($i+1) . " hostname = [$vma_hn[$i]]\n");
			}
		}
		print "-----------\n";
	}

	my @dirstack = ();
	push @dirstack, getcwd;
	chdir $vmcmd_dir;

	my @vms = ();

	my $i = 0;
	my $j = 0;

	for $i (0 .. 1) {
		my $cmd = $vmcmd . ' -U root -P ' . $esxi_pw[$i] . ' --server ' . $esxi_ip[$i] . ' -l';
		open (IN, "$cmd 2>&1 |");
		@outs = <IN>;
		close(IN);
		shift @outs;	# disposing head of the list (blank line)
		foreach (@outs) {
			chomp;
		}
		push @{$vms[$i]}, @outs;
	}

	chdir pop @dirstack;

	my $k = 0;
	for $i (0 .. $#vms) {
		print "\n[ ESXi #" . ($i + 1) . " ]\n-----------\n";
		for $j ( 0 .. $#{$vms[$i]} ) {
			$k++;
			print "[$k] $vms[$i][$j]\n";
		}
	}

	print "\nwhich to add? (1.." . ($k -1) . ") > ";
	$j = <STDIN>;
	chomp $j;
	#print "[D] j[$j] k[$k] #{$vms[0]}[$#{$vms[0]}]\n";
	if ($j !~ /^\d+$/) {
		return -1;
	} elsif ($j == 0) {
		return 0;
	} elsif ($j > $k) {
		return 0;
	} else {
		my $vmname = "";
		if ( $j > $#{$vms[0]} + 1 ) {
			# print "$j	$#{$vms[0]}\n";
			$vmname = $vms[1][$j - $#{$vms[0]} - 2];
		} else {
			$vmname = $vms[0][$j - 1];
		}

		$vmname =~ s/.*\/(.*)\.vmx/$1/;

		# failover-$vmname must be shorter than 31 characters (excluding termination charcter).
		$vmname =~ s/[^\w\s-]//g;
		if (length($vmname) > 22) {
			$vmname = substr ($vmname,0,22);
		}
		$vmname =~ s/-$//;

		if ( $j > $#{$vms[0]} + 1 ) {
			$vmx[1]{$vmname} = $vms[1][$j - $#{$vms[0]} - 2];
			&AddNode(1, $vmname);
		} else {
			$vmx[0]{$vmname} = $vms[0][$j - 1];
			&AddNode(0, $vmname);
		}

		print "\n[I] added [$vmname]\n";
	}
}

sub delVM {
	my $i = 0;
	my $j = 0;
	my @list = ();

	my $k = 0;
	for $i (0 .. $#vmx) {
		print "\n[ ESXi #" . ($i + 1) . " ]\n-----------\n";
		foreach (keys %{$vmx[$i]}) {
			# print "	[$_] [$vmx[$i]{$_}]\n";
			$k++;
			print "[$k]	[$_]\n";
		}
	}

	print "\nwhich to del? (1..$k) > ";
	$j = <STDIN>;
	chomp $j;
	if ($j !~ /^\d+$/){
		return -1;
	} else {
		$k = 0;
		for $i (0 .. $#vmx) {
			foreach (keys %{$vmx[$i]}) {
				$k++;
				if ($j == $k) {
					&DelNode($i, $_);
					print "\n[I] deleted [$_]\n";
					delete $vmx[$i]{$_};
				}
			}
		}
	}
}

sub showVM {
	print "\n";
	my $i = 1;

	for $i (0 .. $#vmx) {
		print "\n[ ESXi #" . ($i + 1) . " ]\n-----------\n";
		foreach (keys %{$vmx[$i]}) {
			# print "	[$_] [$vmx[$i]{$_}]\n";
			print "	[$_]\n";
		}
	}
}

#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	@outs = ();
	&Log("[D] executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	while(<$h>){
		print;
		#&Log("[D]	$_\n");
		chomp;
		push (@outs, $_);
	}
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

##
# Refference
#
# http://www.atmarkit.co.jp/bbs/phpBB/viewtopic.php?topic=46935&forum=10
#
# http://pubs.vmware.com/Release_Notes/en/vcli/65/vsphere-65-vcli-release-notes.html
#	What's New in vSphere CLI 6.5
#	The ActivePerl installation is removed from the Windows installer. ActivePerl or Strawberry Perl version 5.14 or later must be installed separately before installing vCLI on a Windows system.
#
