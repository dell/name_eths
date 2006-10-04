#!/usr/bin/perl -w
#
# eths_to_mactab.pl
# Copyright (c) 2006 Dell, Inc.
#  by Matt Domsch <Matt_Domsch@dell.com>
#  Dual-licensed under the GNU GPL v2 or later
#  or the Mozilla Public License v1.1 or later
#
# This application returns the list of ethernet devices as seen by the OS,
# listing the embedded LAN-on-Motherboard controllers first
# (ascending MAC address order if multiple LOMs exist)
# then listing the NICs on the add-in cards
# (ascending by PCI slot number, then PCI bus number, then MAC address)


use strict;

sub get_hwaddr
{
    my $dev = shift(@_);
    $_ = `/sbin/ip -o link show dev $dev`;
    chomp;
    s|.*link/\S+\s(\S+?)\s.*|$1|;
    $_ = uc; # uppercase $_
    return $_;
}

sub get_pirq
{
    my %pirq = ();
    open(DUMP_PIRQ, "./dump_pirq |") or die "can't open ./dump_pirq: $!";
    while (<DUMP_PIRQ>) {
	next unless $_ =~ /\(slot \w\): (Ethernet|Network)/;
	if (/^Device (\S+:[^\. ]+?)\.0 \(slot (\w)\)/) {
	    # add domain 0000: to the name, delete .0 function part
	    $pirq{"0000:$1"} = $2;
	}
    }
    close(DUMP_PIRQ);
    return \%pirq;
}

sub get_eths
{
    my @eths = ();
    my $e;
    open (IFCONFIG, "/sbin/ifconfig -a |") or die "can't open /sbin/ifconfig: $!";
    while (<IFCONFIG>) {
	next unless $_ =~ /Ethernet/;
	($e) = split(' ', $_);
	push @eths, $e;
    }
    close(IFCONFIG);
    return @eths;
}

sub get_ethtool_info
{
    my $dev = shift(@_);
    my ($driver, $bus);
    open(ETHTOOL, "/usr/sbin/ethtool -i $dev |") or
	open(ETHTOOL, "/sbin/ethtool -i $dev |") or die "can't open ethtool: $!";
    while (<ETHTOOL>) {
	if (/^driver: (.*)/) {
	    $driver = $1;
	}
	if (/^bus-info: (.*)/) {
	    $bus = $1;
	}
    }
    close(ETHTOOL);
    return ($driver, $bus);
}    

my %map;
my @eths = get_eths;
my $pirq_ref = get_pirq;

foreach my $eth (@eths) {
    $map{$eth}{'name'} = $eth;
    $map{$eth}{'mac'}  = get_hwaddr($eth);
    my ($driver, $bus) = get_ethtool_info($eth);
    $map{$eth}{'driver'} = $driver;
    $map{$eth}{'dbdf'} = $bus;
    # delete .x function part, as $PIRQ doesn't have it
    $bus =~ s/\.\S+//;
    $map{$eth}{'bus_dev'} = $bus;
    my $slot = $pirq_ref->{$bus};
    if (defined($slot)) {
	$map{$eth}{'slot'} = $slot;
	if ($slot == 0) {
	    $map{$eth}{'embedded'} = "yes";
	}
	else {
	    $map{$eth}{'embedded'} = "no";
	}
    }
   else {
       printf STDERR "Cannot find location of %s, bus=%s\n", $eth, $bus;
       $map{$eth}{'slot'} = "unknown";
       $map{$eth}{'embedded'} = "unknown";
   }
}

sub embeddeds
{
    my $map_ref = shift(@_);
    my @embeddeds_list = ();
    
    foreach my $eth (keys %map) {
	if ($map{$eth}{'embedded'} =~ "yes") {
	    push @embeddeds_list, $eth;
	}
    }
    return @embeddeds_list;
}

sub addins
{
    my $map_ref = shift(@_);
    my @addin_list = ();
    
    foreach my $eth (keys %map) {
	if ($map{$eth}{'embedded'} =~ "no") {
	    push @addin_list, $eth;
	}
    }
    return @addin_list;
}

sub pci_breadth_first
{
# 0000:0b:07.0
# 0000:0c:08.0
    $map{$a}->{'dbdf'} cmp $map{$b}->{'dbdf'};
}

sub mac
{
    $map{$a}->{'mac'} cmp $map{$b}->{'mac'};
}

sub slot_and_bus_and_mac
{
    $map{$a}->{'slot'} cmp $map{$b}->{'slot'} or
	$map{$a}->{'bus_dev'} cmp $map{$b}->{'bus_dev'} or
	    $map{$a}->{'mac'} cmp $map{$b}->{'mac'};
}


my @embeddeds_list = sort pci_breadth_first embeddeds \%map;
my @addin_list     = sort slot_and_bus_and_mac addins \%map;

my $total = 0;

foreach my $eth (@embeddeds_list) {
    $map{$eth}{'newname'} = "eth$total";
    print "eth$total $map{$eth}{'mac'} # $map{$eth}{'driver'}\n";
    $total++;
}

foreach my $eth (@addin_list){
    $map{$eth}{'newname'} = "eth$total";
    print "eth$total $map{$eth}{'mac'} # $map{$eth}{'driver'}\n";
    $total++;
}

