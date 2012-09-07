use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = '1.3';

%IRSSI = (
	authors		=> 'Valentin Batz',
	contact		=> 'vb\@g-23.org',
	name		=> 'whois0810',
	description	=> 'show accountname and real IP on ircu/ratbox',
	license		=> 'GPLv2',
	url		=> 'http://www.hurzelgnom.homepage.t-online.de/irssi/scripts/quakenet.pl'
);

# adapted by Nei
# further tweaks by jilles 10 May 2006: commented out the whois_oper bits as
# /format whois_oper {whois oper {hilight $1}} does the same, changed texts,
# added support for ratbox's RPL_WHOISACTUALLY, renamed from ircuwhois to
# whois0810.
# more tweaks by jilles 29 Jun 2006: RPL_WHOISHOST (unreal, charybdis 2.1+)

Irssi::theme_register([
	'whois_auth',	'{whois account %|$1}',
	'whois_ip',	'{whois actualip %|$1}',
	'whois_host',	'{whois realhost %|$1}',
	#'whois_oper',	'{whois oper %|$1}',
	'whois_ssl',	'{whois connect. %|$1}'
]);

sub event_whois_default_event {
	#'server event', SERVER_REC, char *data, char *sender_nick, char *sender_address
	my ($server, $data, $snick, $sender) = @_;
	my $numeric = $server->parse_special('$H');
	#if ($numeric eq '313') { &event_whois_oper }
	if ($numeric eq '330') { &event_whois_auth }
	if ($numeric eq '337') { &event_whois_ssl }
	if ($numeric eq '338') { &event_whois_userip }
	if ($numeric eq '378') { &event_whois_host }
}

#sub event_whois_oper {
#	my ($server, $data) = @_;
#	my ($num, $nick, $privileges) = split(/ /, $data, 3);
#	$privileges =~ s/^:(?:is an? )?//;
#	$server->printformat($nick, MSGLEVEL_CRAP, 'whois_oper', $nick, $privileges);
#	Irssi::signal_stop();
#}

sub event_whois_auth {
	my ($server, $data) = @_;
	my ($num, $nick, $auth_nick, $isircu) = split(/ /, $data, 4);
	return unless $isircu =~ / as/; #:is logged in as
	# this one is the same for ircu and ratbox -- jilles
	$server->printformat($nick, MSGLEVEL_CRAP, 'whois_auth', $nick, $auth_nick);
	Irssi::signal_stop();
}

sub event_whois_ssl {
	my ($server, $data) = @_;
	my ($num, $nick, $connection) = split(/ /, $data, 3);
	$connection =~ s/^:(?:is using an? )?//;
	$server->printformat($nick, MSGLEVEL_CRAP, 'whois_ssl', $nick, $connection);
	Irssi::signal_stop();
}

sub event_whois_userip {
	my ($server, $data) = @_;
	my ($nick, $userhost, $ip);
	if ($data =~ /^\S+ (\S+) (\S+@\S+) (\S+) :/) {
		# ircu -- jilles
		$nick = $1;
		$userhost = $2;
		$ip = $3;
		$ip =~ s/^0:/:/;
		$server->printformat($nick, MSGLEVEL_CRAP, 'whois_ip', $nick, $ip);
		$server->printformat($nick, MSGLEVEL_CRAP, 'whois_host', $nick, $userhost);
		Irssi::signal_stop();
	} elsif ($data =~ /^\S+ (\S+) (\S+) :/) {
		# ratbox -- jilles
		$nick = $1;
		$ip = $2;
		$ip =~ s/^0:/:/;
		$server->printformat($nick, MSGLEVEL_CRAP, 'whois_ip', $nick, $ip);
		Irssi::signal_stop();
	}
}

sub event_whois_host {
	my ($server, $data) = @_;
	my ($nick, $userhost, $ip);
	if ($data =~ /^\S+ (\S+) :.* (\S+@\S+)(?: (\S+))?/) {
		$nick = $1;
		$userhost = $2;
		$ip = $3;

		$ip = '' if ($ip eq '255.255.255.255');
		$ip =~ s/^0:/:/;
		$server->printformat($nick, MSGLEVEL_CRAP, 'whois_ip', $nick, $ip) if ($ip);
		$server->printformat($nick, MSGLEVEL_CRAP, 'whois_host', $nick, $userhost);
		Irssi::signal_stop();
	}
}

sub debug {
	use Data::Dumper;
	Irssi::print(Dumper(\@_));
}
#Irssi::signal_register({
#	'whois oper' => [ 'iobject', 'string', 'string', 'string' ],
#}); # fixes oper display in 0.8.10
Irssi::signal_add({
#	'whois oper' => 'event_whois_oper',
#	'event 313' => 'event_whois_oper',
	'event 330' => 'event_whois_auth',
	'event 337' => 'event_whois_ssl',
	'event 338' => 'event_whois_userip',
	'event 378' => 'event_whois_host',
	'whois default event' => 'event_whois_default_event',
});

