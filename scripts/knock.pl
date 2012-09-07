use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";

%IRSSI = (
    authors    => "Jilles Tjoelker",
    contact    => "jilles\@stack.nl",
    name       => "knock",
    description=> "Shows /KNOCK in channel window",
    license    => "BSD (revised)",
);

Irssi::theme_register(['knock' => '{channick_hilight $0} {chanhost_hilight $1} has requested an invite to {channel $2}']);

sub event_knock {
	my ($server, $args, $nick, $address) = @_;

	$args =~ s/^\S+ //;
	if ($args =~ /^(\S*) ([^!]+)!(\S+) /) {
		$server->printformat($1, MSGLEVEL_PUBLIC, 'knock', $2, $3, $1);
	} else {
		$server->print('', $args, MSGLEVEL_CRAP);
		#Irssi::signal_emit("???", $server, $args, $nick, $address);
	}
}

Irssi::signal_add('event 710', 'event_knock');
