# Print the country name in /WHOIS replies
# /SET geoip_city_dat /full/path/to/GeoLiteCity.dat
#
# http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
# Based off of geoip.pl by Toni Viemerö
#
# changed: whois format, charset, regexes, hide if unkown
# --nico
#


use strict;
use Geo::IP;
use Irssi;
use Socket;
use Error qw(:try);

use vars qw($VERSION %IRSSI);
$VERSION = "0.0.4-r1";
%IRSSI = (
    authors         => "Benjamin Rubin, Toni Viemerö",
    name            => "geoip2",
    description     => "Print the users country, city and region name in /WHOIS replies",
    license         => "Public Domain",
    changed         => "Fri Mar 12 14:54:47 EST 2010"
);

sub event_whois {
    my $country = "";
    my $city = "";
    my $region = "";
    my $record;
    my $database = Irssi::settings_get_str("geoip_city_dat");
    my ($server, $data, $nick, $host) = @_;
    my ($me, $nick, $user, $host) = split(" ", $data);
    my $gi = Geo::IP->open($database, GEOIP_CITY_EDITION_REV1);
    
    $gi->set_charset(GEOIP_CHARSET_UTF8);

    if ($host =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
        $record = $gi->record_by_addr($host);
    } elsif ($host =~ /(.*)\.(.*)/) {
        $record = $gi->record_by_name($host); }

    try {
        $country = $record->country_name;
        $city = $record->city;
        $region = $record->region_name;
    }
    catch Error with {
    };

    if ($record) {
       my $data = "$city->$region->$country";
       $server->printformat($nick, MSGLEVEL_CRAP, 'whois_geoip2', $host, $data);
    #} else { $server->printformat($nick, MSGLEVEL_CRAP, 'whois_geoip2', $host, "?"); }
    }
}

Irssi::theme_register([
    'whois_geoip2' => '{whois location %|$1}'
]);

Irssi::signal_add_last('event 311', 'event_whois');
Irssi::settings_add_str("misc", "geoip_city_dat",
                        Irssi::get_irssi_dir() . "/GeoIP.dat");
