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

my $esxiserver = '192.168.137.51';
my $vmcmd_dir = $ENV{'ProgramFiles'} . '\VMware\VMware vSphere CLI\bin';
my $vmcmd = 'vmware-cmd.pl';
my $vmcmd_opt = '-U root -P cluster-0 --server ' . $esxiserver;

my @menu_vMA;
my @menu_iSCSI;

my @esxi_ip = ('0.0.0.0', '0.0.0.0');
#my @esxi_ip = ('192.168.137.51', '192.168.137.52');
my @esxi_pw = ('(none)', '(none)');	# ESXi root password
#my @esxi_pw = ('cluster-0', '(none)');	# ESXi root password
my @vma_hn = ('(none)', '(none)');	# vMA hostname
my @vma_ip = ('0.0.0.0', '0.0.0.0');
my @vms = ();

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
	# use of $esxi_ip[1] should be considered
	my $cmd = $vmcmd . ' -U root -P ' . $esxi_pw[0] . ' --server ' . $esxi_ip[0] . ' -l';

	my @dirstack = ();
	push @dirstack, getcwd;
	chdir $vmcmd_dir;

	open (IN, "$cmd 2>&1 |");
	my @out = <IN>;
	close(IN);
	chdir pop @dirstack; 

	print "\n--------\n";
	my $i = 0;
	foreach (@out) {
		chomp;
		if (! /^$/){
			print "[$i] [$_]\n";
		}
		$i++;
	}

	print "\nwhich to add? (1.." . ($i -1) . ") > ";
	$i = <STDIN>;
	chomp $i;
	if ($i !~ /^\d+$/){
		return -1;
	} else {
		$vms[$i] = $out[$i];
		print "\n[I] added [$vms[$i]]\n";
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