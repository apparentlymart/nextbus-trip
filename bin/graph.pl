#!/usr/bin/perl

use strict;
use NextBusTrip;
use Data::Dumper;

print STDERR "Graph of all hops\n";

my $end_place = NextBusTrip::Place->retrieve(20);

print STDERR "Highlighting routes to ", $end_place->name, "\n";

my @options = NextBusTrip::Option->search(end_place => $end_place);

my %highlight_hops = ();

foreach my $option (@options) {
    my $hop = $option->next_hop;
    $highlight_hops{$hop->id} = 1;
}


print "digraph G {\n";

foreach my $place (NextBusTrip::Place->retrieve_all) {
    my $display_name = $place->name." (".$place->id.")";

    print "\t".$place->id." [label=\"".$display_name."\",shape=rect];";

}

print "\n";

foreach my $hop (NextBusTrip::Hop->retrieve_all) {
    my $display_name = ($hop->is_bus ? $hop->bus_route : 'walk').' ('.$hop->id.')';
    my $color = $highlight_hops{$hop->id} ? 'blue' : 'black';
    print "\t".$hop->start_place->id." -> ".$hop->end_place->id." [label=\"".$display_name."\",color=$color];\n";
}

print "}\n";

