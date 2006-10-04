#!/usr/bin/perl -w

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
	next unless $_ =~ /\(slot \w\): Ethernet/;
	if (/^Device (\S+?) \(slot (\w)\)/) {
	    # add domain 0000: to the name
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
    open(ETHTOOL, "/sbin/ethtool -i $dev |") or die "can't open /sbin/ethtool: $!";
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

sub print_hoh
{
    my $href = shift(@_);
    while ( my ($key, $value) = each(%$href) ) {
	print "$key => ";
	while ( my ($key2, $value2) = each(%$value)) {
	    if (defined($key2) and defined($value2)) {
		print "[ $key2 => $value2 ]";
	    }
	}
	print "\n";
    }
}


my %map;
my @eths = get_eths;
my $pirq_ref = get_pirq;

foreach my $eth (@eths) {
    $map{$eth}{'name'} = $eth;
    $map{$eth}{'mac'}  = get_hwaddr($eth);
    my ($driver, $bus) = get_ethtool_info($eth);
    $map{$eth}{'driver'} = $driver;
    $map{$eth}{'bus'} = $bus;
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

sub mac
{
    $map{$a}->{'mac'} cmp $map{$b}->{'mac'};
}

sub slot_and_bus
{
    $map{$a}->{'slot'} cmp $map{$b}->{'slot'} or
	$map{$a}->{'bus'} cmp $map{$b}->{'bus'};
}


my @embeddeds_list = sort mac embeddeds \%map;
my @addin_list     = sort slot_and_bus addins \%map;

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

