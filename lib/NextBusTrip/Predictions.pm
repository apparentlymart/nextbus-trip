
package NextBusTrip::Predictions;

use strict;
use LWP::UserAgent;
use HTTP::Request;
use XML::XPath;

my %predictions = ();

sub get_next_departure {
    my ($class, $agency, $route, $stop_id, $earliest_time, $filtered_dirs) = @_;

    my %filtered_dirs = ();
    map { $filtered_dirs{$_} = 1 } @$filtered_dirs if $filtered_dirs;

    my $predictions = $predictions{$agency}{"$route\t$stop_id"};

    my $ret = undef;
    if ($predictions) {
        foreach my $prediction (@$predictions) {
            # Predictions are stored as a number of seconds since fetch.
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

sub refresh_predictions {
    my ($class, $to_refresh) = @_;

    my %to_refresh = ();

    foreach my $item (@$to_refresh) {
        $to_refresh{$item->[0]} ||= [];
        push @{$to_refresh{$item->[0]}}, [ $item->[1], $item->[2] ];
    }

    my $ua = LWP::UserAgent->new();
    $ua->agent('Mozilla/4.0 (Compatible)');

    foreach my $agency (keys %to_refresh) {
        my @args = ();

        my @items = @{$to_refresh{$agency}};

        foreach my $item (@items) {
            my $route = $item->[0];
            my $stop_id = $item->[1];

            push @args, 'stops='.$route.'|null|'.$stop_id;
        }

        # First we need to hit the map frontend URL in order to get a
        # session cookie that the server will allow to fetch the data.
        my $cookie = undef;
        {
            my $url = "http://www.nextmuni.com/googleMap/googleMap.jsp?a=".$agency;
            my $req = HTTP::Request->new(GET => $url);
            my $res = $ua->request($req);
            my $set_cookie = $res->header('Set-Cookie');

            if ($set_cookie && $set_cookie =~ m!JSESSIONID=(\w+)!) {
                $cookie = $1;
            }
            else {
                warn "Failed to obtain NextBus session cookie for agency $agency";
                next;
            }
        }

        my $url = "http://www.nextmuni.com/s/COM.NextBus.Servlets.XMLFeed?command=predictionsForMultiStops&a=".$agency."&".join("&", @args);

        my $req = HTTP::Request->new(GET => $url);
        $req->header('Referer' => 'http://www.nextmuni.com/googleMap/googleMap.jsp');
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
                    next;
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



}

1;
