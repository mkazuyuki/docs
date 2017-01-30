#!/usr/bin/perl -w

##
## Monitoring MD resource status.
## Issuing MD recovery operation if MD resource of Primary Node has RED status
##

my $name_md = "md";
my $cmd_clpmdstat = "clpmdstat -m $name_md";
my $cmd_clpmdctrl = "clpmdctrl -f $name_md";
my $ret = 0;

print "[I] ENTER\n";
open (IN, "$cmd_clpmdstat |") or die;
@lines = <IN>;
close(IN);

foreach (@lines){
	#print "[D] $_";
	if (/Mirror Color\s+?RED/){
		# print "[D] [$`][$&][$']";
		my $r = system($cmd_clpmdctrl);
		if ( $r != 0 ){
			print "[E] system($cmd_clpmdctrl) failed [$r]\n";
			$ret = 1;
		}
		elsif ( $? != 0 ){
			print "[E] [$cmd_clpmdctrl] failed [$?]\n";
			$ret = 1;
		}
		else {
			print "[I] system($cmd_clpmdctrl) succeeded\n";
			$ret = 0;
		}
	}
}
print "[I] EXIT [$ret]\n";
exit $ret;
