#!/usr/bin/perl -w

#
# This script creates ECX configuration files (clp.conf and scripts)
#
# Prerequisite package
#	VMware-vSphere-CLI-6.0.0-3561779.exe
#		https://my.vmware.com/jp/web/vmware/details?productId=491&downloadGroup=VCLI60U2
#

use strict;
use Cwd;

my $vmcmd_dir = $ENV{'ProgramFiles'} . '\VMware\VMware vSphere CLI\bin';
my $vmcmd = 'vmware-cmd.pl';

my $CFG_DIR	= "conf";
my $CFG_FILE	= $CFG_DIR . "/clp.conf";

my $TMPL_DIR	= "template";
my $TMPL_CONF	= $TMPL_DIR . "/clp.conf";
my $TMPL_START	= $TMPL_DIR . "/vm-start.pl";
my $TMPL_STOP	= $TMPL_DIR . "/vm-stop.pl";
my $TMPL_MON	= $TMPL_DIR . "/genw-vm.pl";

my @esxi_ip	= ('192.168.137.51', '192.168.137.52');		# ESXi IP address
my @esxi_pw	= ('cluster-0', '(none)');			# ESXi root password
my @vma_hn	= ('vma1', 'vma2');				# vMA hostname
my @vma_ip	= ('192.168.137.205', '192.168.137.206');	# vMA IP address
my $dsname	= "iSCSI";					# iSCSI Datastore
my $vmhba	= "vmhba33";					# iSCSI Software Adapter

#my @esxi_ip	= ('0.0.0.0', '0.0.0.0');	# ESXi IP address
#my @esxi_pw	= ('(none)', '(none)'); 	# ESXi root password
#my @vma_hn	= ('(none)', '(none)'); 	# vMA hostname
#my @vma_ip	= ('0.0.0.0', '0.0.0.0');	# vMA IP address
#my $dsname	= "iSCSI";			# iSCSI Datastore
#my $vmhba	= "vmhba33";			# iSCSI Software Adapter

my %VMs = ();
my @menu_vMA;
my $ret 	= "";

## For DEBUG
###########
#my $file = './DQA-cfg/clp.1.conf';
my $file = $TMPL_CONF;
open(IN, $file);
my @lines = <IN>;
close(IN);
###########

foreach (@lines){
	if (/<group name=\"failover-(.*)\">/) {
		#print "[D] $1\n";
		$VMs{$1} = "";
	}
}

while ( 1 ) {
	if ( ! &select ( &menu ) ) {exit}
}

##
# subroutines
#



#&addVM();
#&DelNode("NMC");
#&ShowNode();
#&DelNode("SV9500_ESXi_B");
#&ShowNode();
#&AddNode("vm1");

#&Save();

# &AddNode("vm1");
#foreach (@lines){
#	chomp;
#	print "$_\n";
#}

#exit;

#
# Changing clp.conf contents for adding new VM group resource
#-------
sub AddNode {
	my $vmname = shift;
	my $i = 0;
	my $gid = 0;

	#
	# Group
	#
	for($i = $#lines; $i > 0; $i--){
		if($lines[$i] =~ /<gid>(.*)<\/gid>/){
			$gid = $1 + 1;
			last;
		}
	}
	for($i = $#lines; $i > 0; $i--){
		if($lines[$i] =~ /<\/group>/){
			last;
		}
		elsif($lines[$i] =~ /<\/root>/){
			print "[D] found </root>\n";
			last;
		}
	}
	#if($i == 0){
	#	$i = $#lines - 1;
	#}

	# inserting @ins into @lines
	my @ins = (
		"	<group name=\"failover-$vmname\">",
		"		<comment> <\/comment>",
		"		<resource name=\"exec\@exec-$vmname\"/>",
		"		<gid>$gid</gid>\n",
		"	</group>\n"
	);
	splice(@lines, $i, 0, @ins);

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
		"			<act><retry>2</retry></act>",
		"		</exec>"
	);
	for($i = $#lines; $i > 0; $i--){
		if($lines[$i] =~ /<\/resource>/){
			last;
		}
	}
	splice(@lines, $i, 0, @ins);

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
	my $vmname = shift;
	my $i = 0;
	my $j = 0;
	my $gid = 0;

	print "[D] deleting [$VMs{$vmname}]\n";
	delete($VMs{$vmname});

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

sub Save {
	my @VM = ();

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
	# Making directry for Group and Monitor resource
	#
	foreach (@lines){
		if (/<group name=\"failover-(.*)\">/) {
			#print "[D] $1\n";
			push @VM, $1;
			my @DIR = ();
			push @DIR, "$CFG_DIR/scripts/failover-$1";
			push @DIR, "$CFG_DIR/scripts/failover-$1/exec-$1";
			push @DIR, "$CFG_DIR/scripts/monitor.s/genw-$1";
			foreach (@DIR) {
				mkdir "$_" if (!-d "$_");
			}
		}
	}

	#
	# Creating start.sh stop.sh genw.sh
	#
	foreach my $vm (keys %VMs) {
		open(IN, "$TMPL_START") or die;
		open(OUT,"> $CFG_DIR/scripts/failover-$vm/exec-$vm/start.sh") or die;
		while (<IN>) {
			#print "[D<] $_" if /%%/;

			if (/%%VMX%%/)		{ s/$&/$VMs{$vm}/;}
			if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
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

		open(IN, "$TMPL_STOP");
		open(OUT,"> $CFG_DIR/scripts/failover-$vm/exec-$vm/stop.sh");
		while (<IN>) {
			#print "[D<] $_" if /%%/;

			if (/%%VMX%%/)		{ s/$&/$VMs{$vm}/;}
			#if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
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

		open(IN, "$TMPL_MON");
		open(OUT,"> $CFG_DIR/scripts/monitor.s/genw-$vm/genw.sh");
		while (<IN>) {
			#print "[D<] $_" if /%%/;

			if (/%%VMX%%/)		{ s/$&/$VMs{$vm}/;}
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

	open(IN, "$TMPL_DIR/genw-esxi-inventory.pl") or die;
	open(OUT,"> $CFG_DIR/scripts/monitor.s/genw-esxi-inventory/genw.sh") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;
		#if (/%%VMX%%/)		{ s/$&/$VMs{$vm}/;}
		if (/%%VMHBA%%/)	{ s/$&/$vmhba/;}
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

	open(IN, "$TMPL_DIR/genw-remote-node.pl") or die;
	open(OUT,"> $CFG_DIR/scripts/monitor.s/genw-remote-node/genw.sh") or die;
	while (<IN>) {
		#print "[D<] $_" if /%%/;
		#if (/%%VMX%%/)		{ s/$&/$VMs{$vm}/;}
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

	return 0;
}

sub menu {
	@menu_vMA = (
		'save and exit',
		'set ESXi#1 IP            : ' . $esxi_ip[0],
		'set ESXi#2 IP            : ' . $esxi_ip[1],
		'set ESXi#1 root password : ' . $esxi_pw[0],
		'set ESXi#2 root password : ' . $esxi_pw[1],
		'set vMA#1 hostname       : ' . $vma_hn[0],
		'set vMA#2 hostname       : ' . $vma_hn[1],
		'set vMA#1 IP             : ' . $vma_ip[0],
		'set vMA#2 IP             : ' . $vma_ip[1],
		'set iSCSI Datastore name : ' . $dsname,
		'set iSCSI Adapter name   : ' . $vmhba,
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
		print "bye\n";
		return 0;
	}
	elsif ( $menu_vMA[$i] =~ /set ESXi#([1..2]) IP/ ) {
		&setESXiIP($1);
	}
	elsif ( $menu_vMA[$i] =~ /set ESXi#([1,2]) root password/ ) {
		&setESXiPwd($1);
	}
	elsif ( $menu_vMA[$i] =~ /set vMA#([1,2]) hostname/ ) {
		&setvMAhostname($1);
	}
	elsif ( $menu_vMA[$i] =~ /set vMA#([1,2]) IP/ ) {
		&setvMAIP($1);
	}
	elsif ( $menu_vMA[$i] =~ /set iSCSI Datastore name/ ) {
		&setDatastoreName;
	}
	elsif ( $menu_vMA[$i] =~ /set iSCSI Adapter name/ ) {
		&setVMHBA;
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

sub setvMAhostname{
	my $i = $_[0] - 1;
	print "[" . $vma_hn[$i] . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$vma_hn[$i] = $ret;
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

sub setDatastoreName{
	print "[" . $dsname . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$dsname = $ret;
	}
}

sub setVMHBA{
	print "[" . $vmhba . "] > ";
	$ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$vmhba = $ret;
	}
}

sub addVM {
	my @dirstack = ();
	push @dirstack, getcwd;
	chdir $vmcmd_dir;

	#### TBD ####
	# use of $esxi_ip[1] should be considered
	my $cmd = $vmcmd . ' -U root -P ' . $esxi_pw[0] . ' --server ' . $esxi_ip[0] . ' -l';
	open (IN, "$cmd 2>&1 |");
	my @out = <IN>;
	close(IN);
	chdir pop @dirstack; 

	print "\n--------\n";
	my $i = 0;
	print "[0] BACK\n";
	foreach (@out) {
		chomp;
		if ( /.*\/(.*)\.vmx$/ ){
			print "[$i] [$_]\n";
		}
		$i++;
	}
	print "\nwhich to add? (1.." . ($i -1) . ") > ";
	my $j = <STDIN>;
	chomp $j;
	if ($j !~ /^\d+$/){
		return -1;
	} elsif ($j == 0){
		return 0;
	} elsif ($j - 1 > $i) {
		return 0;
	} else {
		my $vmname = $out[$j];
		$vmname =~ s/.*\/(.*)\.vmx/$1/;
		$VMs{$vmname} = $out[$j];
		&AddNode($vmname);
		print "\n[I] added [$vmname]\n";
	}
}

sub delVM {
	my $i = 1;
	my @list = ();
	print "\n--------\n";
	print "[0] BACK\n";
	foreach (keys %VMs) {
		print "[$i] [$_]\n";
		push @list, $_;
		$i++;
	}
	print "\nwhich to del? (1.." . ($i -1) . ") > ";
	$i = <STDIN>;
	chomp $i;
	if ($i !~ /^\d+$/){
		return -1;
	} elsif ($i == 0){
		return 0;
	} elsif ($i - 1 > $#list) {
		return 0;
	} else {
		my $vmname = $list[$i-1];
		&DelNode($vmname);
		print "\n[I] deleted [$vmname]\n";
	}
}

sub showVM {
	print "\n";
	my $i = 1;
	foreach (@lines) {
		if (/<group name=\"failover-(.*)\">/) {
			print "\t[" . $i++ . "]\t$1\n";
		}
	}
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