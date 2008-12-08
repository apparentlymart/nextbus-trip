
package NextBusTrip::Trip;

use strict;
use base 'Class::Accessor';
use NextBusTrip::Predictions;

__PACKAGE__->mk_accessors(qw(start_place end_place));

sub new {
    my ($class, $start_place, $end_place) = @_;

    my $self = bless {}, $class;

    $self->start_place($start_place);
    $self->end_place($end_place);

    return $self;
}

sub routes {
    my ($self) = @_;

    return $self->{routes} if $self->{routes};

    my $start_place = $self->start_place;
    my $end_place = $self->end_place;

    my $routes = $start_place->find_routes_to($end_place);

    return $self->{routes} = $routes;
}

sub sensible_routes {
    my ($self) = @_;

    my $routes = $self->routes;

    $routes = [ grep { ! $_->is_ridiculous } @{$routes} ];
    $routes = [ sort { ($a->arrival_time <=> $b->arrival_time) || ($a->wait <=> $b->wait) } @{$routes} ];

    return $routes;
}

sub refresh_bus_predictions {
    my ($self) = @_;

    # Figure out what routes and stops we need to load predictions for.

    my %to_load = ();
    my @to_load = ();

    my $routes = $self->routes;

    foreach my $route (@$routes) {
        foreach my $hop (@{$route->hops}) {
            if ($hop->is_bus) {
                my $place_id = $hop->start_place->id;
                my $bus_agency = $hop->bus_agency;
                my $bus_route = $hop->bus_route;
                my $stop_id = $hop->nextbus_stop_id;

                if ($stop_id) {
                    $to_load{"$bus_agency\t$bus_route\t$stop_id"} = 1;
                }
                else {
                    warn "I don't know the NextBus stop id for $bus_route at ".$hop->start_place->name." (".$hop->start_place->id.")";
                }
            }
        }
    }

    @to_load = map { [ split(/\t/, $_) ] } keys %to_load;

    NextBusTrip::Predictions->refresh_predictions(\@to_load);

}

1;

