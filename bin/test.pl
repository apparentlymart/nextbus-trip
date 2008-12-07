#!/usr/bin/perl

use strict;
use NextBusTrip;
use Data::Dumper;

my $start_place = NextBusTrip::Place->retrieve(1);
#my $start_place = NextBusTrip::Place->retrieve(1);
my $end_place = NextBusTrip::Place->retrieve(20);

print "Finding routes between ", $start_place->name, " and ", $end_place->name, "\n";

my $trip = NextBusTrip::Trip->new($start_place, $end_place);
$trip->refresh_bus_predictions;

my $routes = $trip->sensible_routes();

foreach my $route (@$routes) {
    print "==========================================\n";
    print ucfirst($route->first_step_in_english_with_time)."\n";
    print "To arrive at ".$route->arrival_time_in_english."\n";
    foreach my $hop (@{$route->hops}) {
        print "* ", $hop->in_english, " (".$hop->duration_in_english.")\n";
    }
}



