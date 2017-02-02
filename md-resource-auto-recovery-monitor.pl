#!/usr/bin/perl -w

##
## MD resource monitoring & recovering
##
## This is countermeasure for "RED-Active RED" situation in MD resource.
## Issuung MD recovery commnad when MD resource of Primary Node has RED status
##

my $name_md = "md1";
my $cmd_clpmdstat = "clpmdstat -m $name_md";
my $cmd_clpmdctrl = "clpmdctrl -f $name_md";
my $ret = 0;

&Log("[I] ENTER\n");
open (IN, "$cmd_clpmdstat 2>&1 |") or die;
@lines1 = <IN>;
close(IN);
if ( $! != 0 ) {
	&Log("[E][" . __LINE__ . "] close() failed [$!]\n");
}
elsif ( ($? >> 8) > 125) {
	&Log("[E][" . __LINE__ . "] [$cmd_clpmdstat] returns [". ($? >> 8) . "]\n");
	print @lines1;
	$ret = 1;
}

foreach (@lines1){
	#print "[D] $_";
	if (/Mirror Color\s+?RED/){
		open(IN,"$cmd_clpmdctrl 2>&1 |") or die;
		my @lines2 = <IN>;
		print @lines2;
		close(IN);
		if ( $! != 0 ) {
			&Log("[E][" . __LINE__ . "] close() failed [$!]\n");
			$ret = 1;
		}
		elsif ( $? != 0 ) {
			&Log("[E][" . __LINE__ . "] [$cmd_clpmdctrl] failed [" . ($? >> 8) . "]\n");
			$ret = 1;
		} else {
			&Log("[I][" . __LINE__ . "] system($cmd_clpmdctrl) succeeded\n");
			$ret = 0;
		}
	}
}
&Log("[I] EXIT [$ret]\n");
exit $ret;

sub Log{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
	print "$date $_[0]";
	return 0;
}
