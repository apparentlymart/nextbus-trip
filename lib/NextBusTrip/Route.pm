
package NextBusTrip::Route;

use strict;
use base 'Class::Accessor';

use NextBusTrip::Util qw(format_time);

__PACKAGE__->mk_accessors(qw(hops));

sub new {
    my ($class) = @_;

    my $self = bless {}, $class;

    $self->{hops} = [];
    $self->{wait_times} = {};
    $self->{arrival_times} = {};

    return $self;
}

sub add_hop {
    my ($self, $hop) = @_;

    push @{$self->{hops}}, $hop;
}

sub add_route {
    my ($self, $route) = @_;

    push @{$self->{hops}}, @{$route->{hops}};
}

sub prepend_route {
    my ($self, $route) = @_;

    unshift @{$self->{hops}}, @{$route->{hops}};
    return $self;
}

sub first_step {
    return $_[0]->hops->[0];
}

sub first_step_in_english {
    my ($self) = @_;

    my $hops = $self->hops;

    my $first_hop = $hops->[0];
    my $second_hop = $hops->[1];

    return "You made it!" unless $first_hop;

    if ($first_hop->is_walking) {
        # As a special case, if we're walking to a bus then
        # we say what bus to catch when you get there.
        if ($second_hop && $second_hop->is_bus) {
            return "walk to ".$first_hop->end_place->name." and take the ".$second_hop->bus_route;
        }
    }

    return $first_hop->in_english;

}

sub first_step_in_english_with_time {
    my ($self) = @_;

    my ($wait, $arrival_time) = $self->wait_and_arrival_time;
    my $leave_time = format_time(time() + $wait);

    $wait = int($wait / 60);

    return ($wait > 0 ? "at $leave_time (${wait}min), " : '').$self->first_step_in_english;
}

sub arrival_time_in_english {
    my ($self) = @_;

    my ($wait, $arrival_time) = $self->wait_and_arrival_time;

    return format_time($arrival_time);
}

sub first_hop {
    my ($self) = @_;

    return $self->hops->[0];
}

sub wait_and_arrival_time {
    my ($self, $start_time) = @_;

    $start_time ||= time();

    if (defined($self->{wait_times}{$start_time})) {
        return $self->{wait_times}{$start_time}, $self->{arrival_times}{$start_time};
    }

    my $arrival_time = $start_time;
    my $wait = 0;

    foreach my $hop (@{$self->hops}) {
        $arrival_time = $hop->next_departure_time($arrival_time);
        $arrival_time += $hop->duration;
    }

    # If the first hop is a walk and the second hop is a bus
    # then figure out when we should start walking to avoid
    # waiting at the bus stop.
    my $first_hop = $self->hops->[0];
    my $second_hop = $self->hops->[1];

    if ($first_hop && $second_hop && $first_hop->is_walking && $second_hop->is_bus) {
        my $bus_departure_time = $second_hop->next_departure_time($start_time);
        my $walk_length = $first_hop->duration;
        my $walk_departure_time = $bus_departure_time - $walk_length;
        $wait = $walk_departure_time - $start_time;
    }
    else {
        # Otherwise, the wait time is just how long it is until the first departure.
        if ($first_hop) {
            my $first_departure_time = $first_hop->next_departure_time($start_time);
            $wait = $first_departure_time - $start_time;
        }
    }

    return $self->{wait_times}{$start_time} = $wait, $self->{arrival_times}{$start_time} = $arrival_time;
}

sub arrival_time {
    my ($self) = @_;

    my ($wait, $arrival_time) = $self->wait_and_arrival_time;

    return $arrival_time;
}

sub is_ridiculous {
    my ($self) = @_;

    my $arrival_time = $self->arrival_time;

    # Bus trips without nextbus predictions return the timestamp of the
    # end of UNIX time, so any route that ends on or after that instant
    # is ridiculous.
    return $arrival_time >= 2147483647 ? 1 : 0;
}

1;
