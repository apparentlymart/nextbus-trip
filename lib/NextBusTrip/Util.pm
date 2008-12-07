
package NextBusTrip::Util;

use strict;
use base 'Exporter';

use DateTime;

@NextBusTrip::Util::EXPORT_OK = qw(format_time);

sub format_time {
    my ($ts) = @_;

    my $now = DateTime->now;
    my $dt = DateTime->from_epoch(epoch => $ts);
    $dt->set_time_zone('America/Los_Angeles');
    $now->set_time_zone('America/Los_Angeles');

    if ($now->strftime('%F') eq $dt->strftime('%F')) {
        return $dt->strftime('%R');
    }
    else {
        return $dt->strftime('%F %R');
    }
}
