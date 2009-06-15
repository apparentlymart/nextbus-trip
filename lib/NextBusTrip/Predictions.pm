
package NextBusTrip::Predictions;

use strict;
use LWP::UserAgent;
use HTTP::Request;
use XML::XPath;

my %predictions = ();

my $ua = LWP::UserAgent->new();
$ua->agent('Mozilla/4.0 (Compatible)');

sub get_next_departure {
    my ($class, $agency, $route, $stop_id, $earliest_time, $filtered_dirs) = @_;

    my %filtered_dirs = ();
    map { $filtered_dirs{$_} = 1 } @$filtered_dirs if $filtered_dirs;

    my $predictions = $predictions{$agency}{"$route\t$stop_id"};

    my $ret = undef;
    if ($predictions) {
        foreach my $prediction (@$predictions) {
            my $predicted_time = $prediction->[0];
            my $dir = $prediction->[1];

            next if $filtered_dirs{$dir};
            next if $predicted_time < $earliest_time;

            $ret = $predicted_time;
            last;
        }
    }

    # If we have no prediction for the requested bus,
    # Return a time so stupidly far in the future that this route
    # will get pushed to the back of the list.
    $ret = 2147483647 unless $ret;

    return $ret;

}

sub get_all_departures {
    my ($class, $agency, $route, $stop_id, $earliest_time, $filtered_dirs) = @_;

    my %filtered_dirs = ();
    map { $filtered_dirs{$_} = 1 } @$filtered_dirs if $filtered_dirs;

    my $predictions = $predictions{$agency}{"$route\t$stop_id"};

    my @ret = ();
    if ($predictions) {
        foreach my $prediction (@$predictions) {
            my $predicted_time = $prediction->[0];
            my $dir = $prediction->[1];

            next if $filtered_dirs{$dir};
            next if $predicted_time < $earliest_time;

            push @ret, $predicted_time;
        }
    }

    return @ret;

}

sub refresh_predictions {
    my ($class, $to_refresh) = @_;

    my %to_refresh = ();

    foreach my $item (@$to_refresh) {
        $to_refresh{$item->[0]} ||= [];
        push @{$to_refresh{$item->[0]}}, [ $item->[1], $item->[2] ];
    }

    foreach my $agency (keys %to_refresh) {

        my @items = @{$to_refresh{$agency}};

        # HACK: An agency of "(special)" is used to mark things
        # that aren't walking nor buses, such as bike rides.
        next if $agency eq '(special)';

        # HACK: For now, special case BART to use the "bart" method,
        # and chuck everything else through NextBus. In future
        # this should be configured in the database rather than
        # hard-coded here.

        unless ($agency eq 'bart') {
            $class->refresh_predictions_nextbus($agency, @items);
        }
        else {
            $class->refresh_predictions_bart($agency, @items);
        }

    }

}

sub refresh_predictions_nextbus {
    my ($class, $agency, @items) = @_;

    my @args = ();

    foreach my $item (@items) {
        my $route = $item->[0];
        my $stop_id = $item->[1];

        push @args, 'stops='.$route.'|null|'.$stop_id;
    }

    # First we need to hit the map frontend URL in order to get a
    # session cookie that the server will allow to fetch the data.
    my $cookie = undef;
    my $key = undef;
    {
        my $url = "http://www.nextbus.com/googleMap/googleMap.jsp?a=".$agency;
        my $req = HTTP::Request->new(GET => $url);
        my $res = $ua->request($req);
        my $set_cookie = $res->header('Set-Cookie');

        unless ($res->is_success) {
            warn "Failed to load Google Map page for agency $agency";
            return;
        }

        if ($set_cookie && $set_cookie =~ m!JSESSIONID=(\w+)!) {
            $cookie = $1;
        }
        else {
            warn "Failed to obtain NextBus session cookie for agency $agency";
            return;
        }

        my $content = $res->content;
        if ($content && $content =~ m!keyForNextTime="?(\d+)"?;!) {
            $key = $1;
        }
    }

    push @args, "key=$key";

    my $url = "http://www.nextbus.com/s/COM.NextBus.Servlets.XMLFeed?command=predictionsForMultiStops&a=".$agency."&".join("&", @args);

    my $req = HTTP::Request->new(GET => $url);
    $req->header('Referer' => 'http://www.nextbus.com/googleMap/googleMap.jsp');
    $req->header('Cookie' => 'JSESSIONID='.$cookie);

    my $res = $ua->request($req);
    my $retrieve_time = time();

    if ($res->is_success) {
        my $xml = $res->content;

        eval {
            my $xp = XML::XPath->new(xml => $xml);

            my ($body) = $xp->findnodes('/body');

            unless ($body) {
                warn "$agency predictions document did not contain a body element";
                return;
            }

            my $idx = 0;
            foreach my $preds_elem ($body->getChildNodes) {
                next unless $preds_elem->isa('XML::XPath::Node::Element');
                last unless exists($items[$idx]);
                my $item = $items[$idx];

                my @predictions = ();
                foreach my $pred_elem ($xp->findnodes('direction/prediction', $preds_elem)) {
                    my $seconds = $pred_elem->getAttribute('seconds');
                    my $dir_tag = $pred_elem->getAttribute('dirTag');
                    push @predictions, [ $seconds + $retrieve_time, $dir_tag ];
                }

                $predictions{$agency}{"$item->[0]\t$item->[1]"} = \@predictions;

                $idx++;
            }

        };
        if ($@) {
            warn "Error parsing NextBus predictions: $@";
        }
    }
    else {
        warn "Failed to retrieve NextBus predictions: ".$res->status_line;
    }

}

sub refresh_predictions_bart {
    my ($class, $agency, @items) = @_;

    unless ($agency eq 'bart') {
        warn "The bart predictions method only supports the bart agency";
        return;
    }

    # BART's predictor only selects by stop, and returns all
    # routes on one page. Therefore we only care about the
    # unique stops in our list; we'll do one request for each.
    # TODO: In future, parallelize this.

    my %stops = map { $_->[1] => 1 } @items;
    my @stops = keys(%stops);

    foreach my $stop (@stops) {
        my $url = "http://bart.gov/schedules/eta/index.aspx?stn=".$stop;
        my $req = HTTP::Request->new(GET => $url);
        my $res = $ua->request($req);

        if ($res->is_success) {
            my $html = $res->content;

            if ($html =~ m!<table.*?id="real-time-arrivals-wide">(.*?)</table>!s) {
                my $inner_html = $1;

                while ($inner_html =~ m!<tr.*?>\s*<td>(.*?)</td>\s*<td>(.*?)</td>!sg) {
                    my $route = $1;
                    my $predictions = $2;

                    my @predictions = ();
                    while ($predictions =~ m!(\d+)\s+min!sg) {
                        my $minutes = $1;
                        my $seconds = $minutes * 60;
                        push @predictions, [ time() + $seconds, 'BART' ];
                    }

                    $predictions{$agency}{"$route\t$stop"} = \@predictions;
                }
            }
            else {
                warn "Failed to find the predictions table in BART's HTML for stop $stop";
            }
        }
        else {
            warn "Failed to fetch BART predictions for stop $stop: ".$res->status_line;
        }
    }
}

1;
