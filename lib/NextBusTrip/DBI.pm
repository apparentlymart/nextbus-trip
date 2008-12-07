
package NextBusTrip::DBI;
use base 'Class::DBI';

use strict;
use FindBin;

__PACKAGE__->connection('dbi:SQLite:dbname='.$FindBin::Bin.'/../data.db');

# Trim _id off the end of foreign key accessors
sub accessor_name_for {
    my ($class, $column) = @_;
    $column =~ s/_id$//;
    return $column;
}

1;
