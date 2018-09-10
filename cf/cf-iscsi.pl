#!/usr/bin/perl -w

#
# This script sets the WWN of iSCSI Software Adaptor on ESXi to the iSCSI Target configuration file (/etc/target/saveconfig.json).
# This script requires running iSCSI Cluster.
# This script requires plink.exe (https://the.earth.li/~sgtatham/putty/latest/w32/plink.exe)
#

use strict;
use Cwd;
use FindBin;

#-----------
my @esxi_ip	= ('172.31.255.2', '172.31.255.3');	# ESXi  IP address
my @esxi_pw	= ('cluster-0', 'cluster-0');		# ESXi  root password
my @iscsi_ip	= ('172.31.255.11', '172.31.255.12');	# iSCSI IP address
my @iscsi_pw	= ('NEC123nec!', 'NEC123nec!');		# iSCSI root password
#-----------

my $file	= "iscsi-wwn.sh";			# Template scrit to edit Target configuration
my @wwn 	= ('', '');				# iSCSI WWN to be set to iSCSI#1&2
my @outs = ();

my $vmcmd_dir = $ENV{'ProgramFiles'} . '\VMware\VMware vSphere CLI\bin';
my @dirstack = ();
push @dirstack, getcwd;
chdir $vmcmd_dir;

for (my $i = 0; $i < 2; $i++) {
	my $vmhba = "";
	my $thumbprint = "";

	# Getting thumbprint of ESXi host
	&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " vm process list");
	foreach ( @outs ) {
		if ( /thumbprint: (.+?) / ) {
			$thumbprint = $1;
			last;
		}
	}
	#&Log("[I] thumbprint of ESXi#" . ($i +1) . " ($esxi_ip[$i]) = [$thumbprint]\n");

	# Enabling iSCSI Software Adapter
	&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " -d $thumbprint iscsi software set --enabled true");
	&Log("[I] ---------- [Enabling ESXi#" . ($i + 1) . " iSCSI Software Adapter]\n");
	foreach ( @outs ) {
		&Log("[I] $_\n");
	}

	# Getting vmhba
	&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " -d $thumbprint iscsi adapter list");
	foreach ( @outs ) {
		if ( /^vmhba[\S]+/ ) {
			$vmhba = $&;
		}
	}
	&Log("[I] iSCSI Software Adapter HBA#" . ($i +1) . " = [$vmhba]\n");

	# Getting WWN
	&execution ("esxcli -u root -p " . $esxi_pw[$i] . " -s " . $esxi_ip[$i] . " -d $thumbprint iscsi adapter get -A $vmhba");
	foreach ( @outs ) {
		if ( /^   Name: (.+)/ ) {
			$wwn[$i] = $1;
			&Log("[I] iSCSI Software Adapter WWN#" . ($i + 1) . " = [" . $wwn[$i]. "]\n");
			&Log("[I] ----------\n");
		}
	}
}
chdir pop @dirstack;

# Editing template
&Log("[I] Creating  $file\n");
open ( IN, "$FindBin::Bin\\script\\$file" ) or die;
my @lines = <IN>;
close IN;
open OUT, "> $FindBin::Bin\\$file" or die;
foreach ( @lines ) {
	if ( /%%WWN1%%/ ) {
		s/$&/$wwn[0]/;
	}
	elsif (/%%WWN2%%/) {
		s/$&/$wwn[1]/;
	}
	print OUT;
}
close OUT;

# Setting WWN
&Log("[I] Executing $file on iSCSI#1\n");
&execution(".\\plink.exe -l root -pw $iscsi_pw[0] $iscsi_ip[0] -m $file");
&Log("[I] Executing $file on iSCSI#2\n");
&execution(".\\plink.exe -l root -pw $iscsi_pw[1] $iscsi_ip[1] -m $file");

&Log("[I] Deleting  $file\n");
unlink ( ".\\$file" ) or die;

exit;

#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	&Log("[D] executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	@outs = ();
	while(<$h>){
		chomp;
		push (@outs, $_);
		&Log("[D]	$_\n");
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
