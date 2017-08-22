#!/usr/bin/perl -w

use strict;

my @menu_vMA;
my @menu_iSCSI;
&init;

while ( 1 ) {
	if ( &model ( &view ) ) {exit}
}

sub init {
	%cf = (
		$node1 -> $hostname,
		$node1 -> $ipaddr
	);

	@menu_vMA = (
		"\n",
		"--------\n",
		"0 : exit\n",
		"node1 Hostname",
		"node2 Hostname",
		"node1 IP",
		"node2 IP",
		"1 : add VM\n",
		"2 : del VM\n",
		"3 : show VM\n",
		"4 : IP \n",
		"4 : set iSCSI cluster\n",
		"> "
	);
	@menu_iSCSI = (
		"\n",
		"--------\n",
		"0 : exit\n",
		"1 : set IP\n",
		"2 : show IP\n",
		"4 : set vMA cluster\n",
		"> "
	);
}

sub view {
	print @menu_vMA;
	my $ret = <STDIN>;
	chomp $ret;
	return $ret;
}

sub model {
	my $ret = $_[0];
	if ( $ret eq "0" ) {
		print "[$ret]\n";
	}
	elsif ( $ret eq "1" ) {
		print "[$ret]\n";
	}
	elsif ( $ret eq "2" ) {
		print "[$ret]\n";
	}
	elsif ( $ret eq "3" ) {
		print "[$ret]\n";
	}
	else {
		print "Invalid.\n";
	}
	return $ret;
}
