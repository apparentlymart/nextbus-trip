
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

sub initial_walk_time {
    my ($self) = @_;

    my $first_hop = $self->first_hop;

    return $first_hop->is_walking ? $first_hop->duration : 0;
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

sub all_waits_and_arrival_times {
    my ($self, $start_time) = @_;

    # This is kinda hacky, since I'm shoe-horning support for multiple
    # departures in after the fact. Whatever.

    $start_time ||= time();

    my $first_hop = $self->hops->[0];
    my $second_hop = $self->hops->[1];
    my $base_delay = 0;
    my $predictions_hop = undef;

    if ($first_hop->is_walking && $second_hop) {
        $base_delay = $first_hop->duration;
        $start_time += $base_delay;
        $predictions_hop = $second_hop;
    }
    else {
        $predictions_hop = $first_hop;
    }

    my @predictions = $predictions_hop->all_departure_times;
    use Data::Dumper;
    print STDERR Data::Dumper::Dumper(\@predictions);

    my @ret = ();

    foreach my $p_start_time (@predictions) {
        # Now we just call into the singular wait_and_arrival_time
        # method using the prediction start time - 1 as the start time,
        # guaranteeing that we'll get back the wait and arrival time
        # for that particular prediction.
        # (This is the really hacky part.)

        my $start_time_offset = $p_start_time - $start_time;
        my ($wait, $arrival_time) = $self->wait_and_arrival_time($p_start_time - 1);

        next if $self->_time_is_ridiculous($arrival_time);

        $wait += $start_time_offset;
        #$wait -= $base_delay;

        my $leave_time = format_time($start_time + $wait);

        my $wait_minutes = int($wait / 60);

        my $desc = ($wait_minutes > 0 ? "at $leave_time (${wait_minutes}min), " : '').$self->first_step_in_english;

        push @ret, [ $wait, $arrival_time, $desc, format_time($arrival_time) ];
    }

    return @ret;
}

sub wait {
    my ($self) = @_;

    my ($wait, $arrival_time) = $self->wait_and_arrival_time;

    return $wait;
}

sub arrival_time {
    my ($self) = @_;

    my ($wait, $arrival_time) = $self->wait_and_arrival_time;

    return $arrival_time;
}

sub is_ridiculous {
    my ($self) = @_;

    my $arrival_time = $self->arrival_time;

    return $self->_time_is_ridiculous($arrival_time);
}

sub _time_is_ridiculous {
    my ($self, $arrival_time) = @_;

    # Bus trips without nextbus predictions return the timestamp of the
    # end of UNIX time, so any route that ends on or after that instant
    # is ridiculous.
    return $arrival_time >= 2147483647 ? 1 : 0;
}

1;
