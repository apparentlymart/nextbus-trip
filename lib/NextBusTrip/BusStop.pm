
package NextBusTrip::BusStop;

use base qw(NextBusTrip::DBI);

__PACKAGE__->table('bus_stop');
__PACKAGE__->columns(All => qw(id place_id bus_agency bus_route bus_stop_id));
__PACKAGE__->has_a(place_id => 'NextBusTrip::Place');


# By default we snip _id from the end of accessors, but bus_stop_id
# really is an id so let's not snip that one.
sub accessor_name_for {
    my ($class, $column) = @_;

    return $column if $column eq 'bus_stop_id';
    return $class->SUPER::accessor_name_for($column);
}

1;
