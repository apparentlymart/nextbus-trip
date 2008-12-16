
package NextBusTrip::Place;

use base qw(NextBusTrip::DBI);
use strict;
use vars qw(%seen_hops);

__PACKAGE__->table('place');
__PACKAGE__->columns(All => qw(id name));
__PACKAGE__->has_many(options => 'NextBusTrip::Option', 'start_place_id');
__PACKAGE__->has_many(outgoing_hops => 'NextBusTrip::Hop', 'start_place_id');
__PACKAGE__->has_many(incoming_hops => 'NextBusTrip::Hop', 'end_place_id');
__PACKAGE__->has_many(bus_stops => 'NextBusTrip::BusStop', 'place_id');

sub find_routes_to {
    my ($self, $end_place, $previous_hop) = @_;

    my @options = $self->options(end_place_id => $end_place);

    my @ret = ();
    local %seen_hops = %seen_hops;

    foreach my $option (@options) {
        my $route = NextBusTrip::Route->new();

        my $next_hop = $option->next_hop;
        my $next_place = $next_hop->end_place;

        next if $seen_hops{$next_hop->id};
        next if defined($previous_hop) && $previous_hop->is_walking && $next_hop->is_walking;

        $route->add_hop($next_hop);
        $seen_hops{$next_hop->id} = 1;

        if ($next_place->id != $end_place->id) {
            my $next_routes = $next_place->find_routes_to($end_place, $next_hop);
            foreach my $next_route (@$next_routes) {
                push @ret, $next_route->prepend_route($route);
            }
        }
        else {
            push @ret, $route;
        }

    }

    return \@ret;

}

1;

