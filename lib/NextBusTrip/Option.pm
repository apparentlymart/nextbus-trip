
package NextBusTrip::Option;

use strict;
use base qw(NextBusTrip::DBI);

__PACKAGE__->table('option');
__PACKAGE__->columns(All => qw(id start_place_id end_place_id next_hop_id));
__PACKAGE__->has_a(start_place_id => 'NextBusTrip::Place');
__PACKAGE__->has_a(end_place_id => 'NextBusTrip::Place');
__PACKAGE__->has_a(next_hop_id => 'NextBusTrip::Hop');
