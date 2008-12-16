#!/usr/bin/perl

use strict;
use CGI;
use Template;
use FindBin;
use CGI::Carp qw(fatalsToBrowser);

my $base_dir;
BEGIN {
    $base_dir = $FindBin::Bin."/..";
}

use lib "$base_dir/lib";

use NextBusTrip;

my $cgi = new CGI;
my $t = new Template(
    INCLUDE_PATH => "$base_dir/templates",
);

header();

my $start_place_id = $cgi->param('s') + 0;
my $end_place_id = $cgi->param('e') + 0;

my $current_uri = $ENV{REQUEST_URI};

unless ($start_place_id) {

    my @all_places = sort { $a->name cmp $b->name } NextBusTrip::Place->retrieve_all();

    $t->process("choose_start.tt", {
        places => \@all_places,
        current_uri => $current_uri,
    });

    exit();
}

my $start_place = NextBusTrip::Place->retrieve($start_place_id);
die "No such start place" unless $start_place;

unless ($end_place_id) {

    # Find all of the places that we actually know how to get to
    # from the given start place;

    my @options = $start_place->options;

    my %end_place_options = ();
    map { $end_place_options{$_->end_place->id} = 1 } @options;

    my @available_places = map { NextBusTrip::Place->retrieve($_) } keys %end_place_options;

    $t->process("choose_end.tt", {
        places => \@available_places,
        current_uri => $current_uri,
        start_place => $start_place,
    });

    exit();

}

my $end_place = NextBusTrip::Place->retrieve($end_place_id);
die "No such end place" unless $end_place;

my $trip = NextBusTrip::Trip->new($start_place, $end_place);
$trip->refresh_bus_predictions;

my $routes = $trip->sensible_routes();

my %first_steps_used = ();

my @choices = ();

foreach my $route (@$routes) {

    my $first_step = $route->first_step;

    my $next_place = $first_step->end_place;
    my $next_url = "./?s=".$next_place->id."&e=".$end_place->id;

    my $initial_walk_time = $route->initial_walk_time;

    foreach my $possible ($route->all_waits_and_arrival_times) {
        my ($wait, $arrival_time, $first_step_desc, $arrival_time_in_english) = @$possible;

        next if ($first_steps_used{$first_step_desc});

        push @choices, {
            url => $next_url,
            desc => ucfirst($first_step_desc),
            arrive_time => $arrival_time_in_english,
            arrive_time_unix => $arrival_time,
            initial_walk_time => $initial_walk_time,
        };

        $first_steps_used{$first_step_desc} = 1;

    }


}

@choices = sort {
    $a->{arrive_time_unix} <=> $b->{arrive_time_unix} || $a->{initial_walk_time} <=> $b->{initial_walk_time}
} @choices;

$t->process("choose_step.tt", {
    choices => \@choices,
    start_place => $start_place,
    end_place => $end_place,
});



my $sent_header = 0;
sub header {
    unless ($sent_header) {
        print "Content-type: text/html\n\n";
        $sent_header = 1;
    }

}

