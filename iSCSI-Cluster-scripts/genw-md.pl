#!/usr/bin/perl -w

#
# "RED-Active RED" monitor
#
# This provides countermeasure for "RED-Active RED" situation in the MD resource.
# Issuung the MD force recovery command when the active MD resource gets RED status.
#

my $ret = 0;
my @lines = ();
my $name_md = "";

# Getting the MD name
&execution("clpmdstat -l");
foreach (@lines) {
        if (/<(.+)>/) {
                push(@name_md, $1);
        }
}

# Checking the MD status
foreach my $md (@name_md) {
    &execution("clpmdstat -m \'$md\'");
    foreach my $li (@lines){
        if ($li =~ /Mirror Color\s+?RED/){
			# Forced Recovering the MD
			&Log("[D]\t$li");
			&execution("clpmdctrl -f $md");
			foreach (@lines) {
				chomp;
			&Log("[D]\t$_\n");
			}
            last;
        }
    }
}
exit $ret;

#-------------------------------------------------------------------------------
sub execution {
	my $cmd = shift;
	&Log("[D] executing [$cmd]\n");
	open(my $h, "$cmd 2>&1 |") or die;
	@lines = <$h>;
	#foreach (@lines) {
	#	chomp;
	#	&Log("[D]\t$_\n");
	#} 
	close($h); 
	&Log(sprintf("[D] result ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
}

sub Log{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min,
	   $sec;
	print "$date $_[0]";
	return 0;
}
