
package NextBusTrip::Hop;

use base qw(NextBusTrip::DBI);

__PACKAGE__->table('hop');
__PACKAGE__->columns(All => qw(id start_place_id end_place_id duration bus_agency bus_route filter_dirs));
__PACKAGE__->has_a(start_place_id => 'NextBusTrip::Place');
__PACKAGE__->has_a(end_place_id => 'NextBusTrip::Place');

use NextBusTrip::Predictions;

sub next_departure_time {
    my ($self, $earliest) = @_;

    my $nextbus_stop_id = $self->nextbus_stop_id;

    if ($nextbus_stop_id) {
        my $agency = $self->bus_agency;
        my $route = $self->bus_route;
        my $filtered_dirs = $self->filter_dirs ? [ split(',', $self->filter_dirs) ] : undef;

        my $next_departure = NextBusTrip::Predictions->get_next_departure($self->bus_agency, $self->bus_route, $nextbus_stop_id, $earliest, $filtered_dirs);

        return $next_departure;
    }
    else {
        return $earliest;
    }

}

sub all_departure_times {
    my ($self, $earliest) = @_;

    $earliest ||= time();

    my $nextbus_stop_id = $self->nextbus_stop_id;

    if ($nextbus_stop_id) {
        my $agency = $self->bus_agency;
        my $route = $self->bus_route;
        my $filtered_dirs = $self->filter_dirs ? [ split(',', $self->filter_dirs) ] : undef;

        return NextBusTrip::Predictions->get_all_departures($self->bus_agency, $self->bus_route, $nextbus_stop_id, $earliest, $filtered_dirs);
    }
    else {
        return ($earliest);
    }

}

sub next_arrival_time {
    my ($self, $earliest_departure) = @_;

    my $start_time = $self->next_departure_time($earliest);
    return $start_time + $self->duration;
}

sub nextbus_stop_id {
    my ($self) = @_;

    if ($self->is_bus) {
        my $agency = $self->bus_agency;
        my $route = $self->bus_route;
        my ($stop) = $self->start_place->bus_stops(bus_agency => $agency, bus_route => $route);
        return $stop ? $stop->bus_stop_id : undef;
    }
    else {
        return undef;
    }
}

sub duration_in_english {
    my ($self) = @_;

    return int($self->duration / 60)."min";
}

sub in_english {
    my ($self) = @_;

    if ($self->bus_route) {
        return "take the ".$self->bus_route." to ".$self->end_place->name;
    }
    else {
        return "walk to ".$self->end_place->name;
    }
}

sub is_walking {
    my ($self) = @_;

    return $self->bus_route ? 0 : 1;
}

sub is_bus {
    my ($self) = @_;

    return $self->bus_route ? 1 : 0;
}

1;

