#!/usr/bin/perl -w

my @lines;
my @esxi_ip = ();
my @esxi_pw = ();

$esxi_ip[0] = '%%VMK1%%';
$esxi_ip[1] = '%%VMK2%%';
$esxi_pw[0] = '%%VMKPW1%%';
$esxi_pw[1] = '%%VMKPW2%%';

&setCredstore;

#-------------------------------------------------------------------------------
sub setCredstore {
	for (my $i = 0; $i < 2; $i++) {
		my $cmd = "/usr/lib/vmware-vcli/apps/general/credstore_admin.pl";
		&execution("$cmd add -s $esxi_ip[$i] -u root -p $esxi_pw[$i]");
		&execution("esxcli -s $esxi_ip[$i] system version get");
		foreach(@lines){
			if (/thumbprint: (.*) \(/){
				&execution("$cmd add -s $esxi_ip[$i] -t $1");
			}
		}
	}

	# Preparing SSH
	#&execution("cp /root/.ssh/id_rsa.pub /tmp");
	#&execution("chmod 666 /tmp/id_rsa.pub");
}
#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	&Log("[D] executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	while(<$h>){
		#chomp;
		#&Log("[D]	$_\n");
		print;
		push @lines, $_;
	}
	#@lines = <$h>;
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
