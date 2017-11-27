#!/usr/bin/perl -w

#
# This script creates ECX configuration files (clp.conf and scripts)
#
# Prerequisite package
#	VMware-vSphere-CLI-6.0.0-3561779.exe
#		https://my.vmware.com/jp/web/vmware/details?productId=491&downloadGroup=VCLI60U2
#

#
# 2017/11/14	スクリプトを抜けるときに、start.sh、stop.sh、monitor.sh を作成すること。
#

use strict;
use Cwd;

#----------------
#use XML::Simple;
use Data::Dumper;
use XML::LibXML qw();

my $parser = XML::LibXML->new();
my $root = $parser->parse_file('./DQA-cfg/clp.conf');
#----------------

my $vmcmd_dir = $ENV{'ProgramFiles'} . '\VMware\VMware vSphere CLI\bin';
my $vmcmd = 'vmware-cmd.pl';

my $CFG_DIR	= "conf";
my $CFG_FILE	= $CFG_DIR . "/clp.conf";

my $TMPL_DIR	= "template";
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

my @vms = ();

my @menu_vMA;

## For DEBUG
###########
my $file = './DQA-cfg/clp.1.conf';
open(IN, $file);
my @lines = <IN>;
close(IN);

&DelNode("NMC");
#&ShowNode();
&DelNode("SV9500_ESXi_B");
#&ShowNode();
&AddNode("vm1");
&Save();

# &AddNode("vm1");
foreach (@lines){
	chomp;
#	print "$_\n";
}
exit;

$root->toFile('a.xml');
exit;

#
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
	}
	my @ins = (
		"	<group name=\"failover-$vmname\">",
		"		<comment> <\/comment>",
		"		<resource name=\"exec\@exec-$vmname\"/>",
		"		<gid>$gid</gid>",
		"	</group>"
	);
	if($i == 0){
		$i = $#lines - 1;
	}
	# inserting @ins into @lines
	splice(@lines,$i+1,0,@ins);

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
	splice(@lines,$i,0,@ins);

	#
	# Create start.sh stop.sh
	#
	my $DIR = "conf/scripts/failover-$vmname/exec-$vmname";
	mkdir $DIR if (!-d $DIR);
	#open (OUT, "> $DIR/start.sh");
	open (IN,  "template/vm-start.pl");
	while(<IN>){
		if (/%%VMX%%/) {
	#		s/%%VMX%%/$vmx/;
		}
	}
	
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
#	my $rsname = "";	# resource name
	my $i = 0;
	my $j = 0;
	my $gid = 0;

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

sub ShowNode {
	my $i = 1;
	foreach (@lines) {
		if (/<group name=\"failover-(.*)\">/) {
			print "\t[" . $i++ . "]\t$1\n";
		}
	}
}

sub Save {
	my @VM = ();

	open(OUT, "> $CFG_FILE");
	print OUT @lines;
	close(OUT);

	foreach (@lines){
		my @DIR = ();
		if (/<group name=\"failover-(.*)\">/) {
			print "[D] $1\n";
			push @VM;
			push @DIR, "$CFG_DIR/scripts/failover-$1";
			push @DIR, "$CFG_DIR/scripts/failover-$1/exec-$1";
			push @DIR, "$CFG_DIR/scripts/monitor.s/genw-$1";
			foreach (@DIR) {
				mkdir "$_" if (!-d "$_");
			}
		}
	}

	foreach (@VM) {
		
	}

	return 1;
	
	open(IN, "$TMPL_START");
	open(OUT,"> $CFG_DIR/scripts/aaa");
	while (<IN>) {
		chomp;
		print "$_\n";
		
		if (/%%VMX%%/)		{			print "$&\n" }
		if (/%%VMHBA%%/)	{ s/$&/$vmhba/;		print "$_\n" }
		if (/%%DATASTORE%%/)	{ s/$&/$dsname/;	print "$_\n" }
		if (/%%VMK1%%/)		{ s/$&/$esxi_ip[0]/;	print "$_\n" }
		if (/%%VMK2%%/)		{ s/$&/$esxi_ip[1]/;	print "$_\n" }
		if (/%%VMA1%%/)		{ s/$&/$vma_ip[0]/;	print "$_\n" }
		if (/%%VMA2%%/)		{ s/$&/$vma_ip[1]/;	print "$_\n" }
	}
	close(OUT);
	close(IN);
}

########
my $simple = XML::Simple->new (ForceArray => 1, KeepRoot => 1);
#my $data = $simple->XMLin('./apply/clp.conf');
#my $data = $simple->XMLin('./DQA-cfg/clp.conf');
my $data = $simple->XMLin('./vma-cfg/clp.conf');

#print Dumper($data);

#foreach my $s1 (keys %{$data->{root}[0]->{group}}){
#	print  "[D] group	[$s1]\n";
#	printf "[D]	resource	[%s]\n", %{$data->{root}[0]->{group}->{$s1}->{resource}};
#	printf "[D]	gid		[%s]\n",   $data->{root}[0]->{group}->{$s1}->{gid}[0];
#	if ( $data->{root}[0]->{group}->{$s1}->{comment}[0] !~ /0/ ){
#	printf "[D]	comment		[%s]\n",   $data->{root}[0]->{group}->{$s1}->{comment}[0];
#	} else {
#	print "[D]	comment		[ ]\n";
#	}
#}

#=======
#print Dumper($data->{root}[0]->{group}->{'failover-SV95'});
#print Dumper($data->{root}[0]->{group}->{'failover-UCE2016SP1'});

#$data->{root}[0]->{group}->{'failover-cent'}->{resource}->{'exec@exec-cent'} = {};
#$data->{root}[0]->{group}->{'failover-cent'}->{gid} = ['100'];
#$data->{root}[0]->{group}->{'failover-cent'}->{comment} = [{}];

#print Dumper($data->{root}[0]->{group}->{'failover-cent'});

#print Dumper( $data->{root}[0]->{resource}[0]->{exec}->{'exec-SV95'} );
#print Dumper( $data->{root}[0]->{resource}[0]->{exec}->{'exec-SV95'}->{parameters} );

#print Dumper( $data->{root}[0]->{resource}[0]->{exec}->{'exec-SV95'}->{parameters}[0]->{userlog}[0] );
#print Dumper( $data->{root}[0]->{resource}[0]->{exec}->{'exec-SV95'}->{parameters}[0]->{logrotate}[0]->{use}[0] );
#print Dumper( $data->{root}[0]->{resource}[0]->{exec}->{'exec-SV95'}->{parameters}[0]->{deact}[0]->{path}[0] );
#print Dumper( $data->{root}[0]->{resource}[0]->{exec}->{'exec-SV95'}->{parameters}[0]->{act}[0]->{path}[0] );

my $s = "exec-cent7";
#print Dumper( $data->{root}[0]->{resource}[0]->{exec}->{$s}->{parameters}[0]->{userlog}[0] );
#print Dumper( $data->{root}[0]->{resource}[0]->{exec}->{$s}->{parameters}[0]->{logrotate}[0]->{use}[0] );
#print Dumper( $data->{root}[0]->{resource}[0]->{exec}->{$s}->{parameters}[0]->{deact}[0]->{path}[0] );
#print Dumper( $data->{root}[0]->{resource}[0]->{exec}->{$s}->{parameters}[0]->{act}[0]->{path}[0] );

#print Dumper($data->{root}[0]->{resource}[0]);
#print Dumper($data->{root}[0]->{resource}[0]->{exec});
#print Dumper($data->{root}[0]->{resource}[0]->{exec}->{'exec-cent7'});

print Dumper($data->{root}[0]->{resource}[0]->{exec}->{'exec-cent7'});
#exit;
#print Dumper($data->{root}[0]->{resource}[0]->{exec}->{$s}->{parameters}[0]);
#print Dumper($data->{root}[0]->{resource}[0]->{exec}->{$s}->{act}[0]->{retry}[0]);
#print Dumper($data->{root}[0]->{resource}[0]->{exec}->{$s}->{comment}[0]);

$s = "exec-vm1";

$data->{root}[0]->{resource}[0]->{exec}->{"$s"}->{act}[0]->{retry}[0]	= '2';
$data->{root}[0]->{resource}[0]->{exec}->{"$s"}->{comment}[0]	= ' ';
$data->{root}[0]->{resource}[0]->{exec}->{"$s"}->{parameters}[0]->{userlog}[0]		= "/opt/nec/clusterpro/log/" . $s . ".log";
$data->{root}[0]->{resource}[0]->{exec}->{"$s"}->{parameters}[0]->{logrotate}[0]->{use}[0]= '1';
$data->{root}[0]->{resource}[0]->{exec}->{"$s"}->{parameters}[0]->{deact}[0]->{path}[0]	= 'stop.sh';
$data->{root}[0]->{resource}[0]->{exec}->{"$s"}->{parameters}[0]->{act}[0]->{path}[0]	= 'start.sh';
#print Dumper($data->{root}[0]->{resource}[0]->{exec}->{$s});

#print Dumper( $data->{root}[0]->{resource}[0] );

#=======

$simple->XMLout($data,
	NoAttr=>1,
	KeepRoot => 1,
	OutputFile => 'a.xml',
	XMLDecl    => "<?xml version=\"1.0\" encoding=\"ASCII\"?>",
);

exit;
########





while ( 1 ) {
	if ( ! &select ( &menu ) ) {exit}
}

##
# subroutines
#

sub menu {
	@menu_vMA = (
		'  exit',
		'* set ESXi#1 IP            : ' . $esxi_ip[0],
		'* set ESXi#2 IP            : ' . $esxi_ip[1],
		'* set ESXi#1 root password : ' . $esxi_pw[0],
		'* set ESXi#2 root password : ' . $esxi_pw[1],
		'  set vMA#1 hostname       : ' . $vma_hn[0],
		'  set vMA#2 hostname       : ' . $vma_hn[1],
		'  set vMA#1 IP             : ' . $vma_ip[0],
		'  set vMA#2 IP             : ' . $vma_ip[1],
		'  set iSCSI Datastore name : ' . $dsname,
		'  set iSCSI Adapter name   : ' . $vmhba,
		'* add VM',
		'  del VM',
		'  show VM'
	);
	my $i = 0;
	print "\n--------\n";
	foreach (@menu_vMA) {
		print "[" . ($i++) . "] $_\n";  
	}
	print "\n(*) able to select\n(0.." . ($i - 1) . ") > ";

	my $ret = <STDIN>;
	chomp $ret;
	return $ret;
}

sub select {
	my $i = $_[0];
	if ($i !~ /^\d+$/){
		print "invalid (should be numeric)\n";
		return -1;
	}
	elsif ( $menu_vMA[$i] =~ /exit/ ) {
		print "exit\n";
	}
	elsif ( $menu_vMA[$i] =~ /set ESXi#([1..2]) IP/ ) {
		&setESXiIP($1);
	}
	elsif ( $menu_vMA[$i] =~ /set ESXi#([1,2]) root password/ ) {
		&setESXiPwd($1);
	}
	elsif ( $menu_vMA[$i] =~ /add VM/ ) {
		&addVM;
	}
	else {
		print "[$i] Invalid.\n";
	}
	return $i;
}

sub setESXiIP {
	my $i = $_[0] - 1;
	print "[" . $esxi_ip[$i] . "] > ";
	my $ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$esxi_ip[$i] = $ret;
	}
}

sub setESXiPwd{
	my $i = $_[0] - 1;
	print "[" . $esxi_pw[$i] . "] > ";
	my $ret = <STDIN>;
	chomp $ret;
	if ($ret ne "") {
		$esxi_pw[$i] = $ret;
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
	foreach (@out) {
		chomp;
		if ($i == 0) {
			print "[$i] BACK\n";
		}
		elsif (! /^$/){
			print "[$i] [$_]\n";
		}
		$i++;
	}

	print "\nwhich to add? (1.." . ($i -1) . ") > ";
	$i = <STDIN>;
	chomp $i;
	if ($i !~ /^\d+$/){
		return -1;
	} elsif ($i == 0){
		return 0;
	} else {
		#$vms[$i] = $out[$i];
		my $vmname = $out[$i];
		$vmname =~ s/.*\/(.*)\.vmx/$1/;
		my $group_name = "failover-" . $vmname;
		my $resource_name = 'exec@exec-' . $vmname;

		my $gid = 0;

#        <group name="failover-UM4730">
#                <comment> </comment>
#                <resource name="exec@exec-UM4730"/>
#                <gid>9</gid>
#        </group>
		
		foreach my $s1 (keys %{$data->{root}[0]->{group}}){
			print "[D] " . $data->{root}[0]->{group}->{$s1}->{gid}[0] . "[$s1]" . "\n";
			if ( $gid < $data->{root}[0]->{group}->{$s1}->{gid}[0] ){
				$gid = $data->{root}[0]->{group}->{$s1}->{gid}[0];
			}
		}
		$gid++;

		$data->{root}[0]->{group}->{$group_name}->{resource}->{$resource_name} = {};
		$data->{root}[0]->{group}->{$group_name}->{gid} = ["$gid"];
		$data->{root}[0]->{group}->{$group_name}->{comment} = [{}];
		#print Dumper($data->{root}[0]->{group}->{$group_name});

		$resource_name = 'exec-' . $vmname;
		$data->{root}[0]->{resource}[0]->{exec}->{$resource_name}->{parameters}[0]->{userlog}[0]		= "/opt/nec/clusterpro/log/" . $resource_name . ".log";
		$data->{root}[0]->{resource}[0]->{exec}->{$resource_name}->{parameters}[0]->{logrotate}[0]->{use}[0]	= '1';
		$data->{root}[0]->{resource}[0]->{exec}->{$resource_name}->{parameters}[0]->{deact}[0]->{path}[0]	= 'stop.sh';
		$data->{root}[0]->{resource}[0]->{exec}->{$resource_name}->{parameters}[0]->{act}[0]->{path}[0]		= 'start.sh';
		#print Dumper($data->{root}[0]->{resource}[0]->{exec}->{$resource_name]->{parameters}[0]);

		print "\n[I] added [$group_name]\n";
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