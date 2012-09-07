use strict;
use vars qw($VERSION %IRSSI);

use LWP::UserAgent;

use Irssi;
$VERSION = '20090206';
%IRSSI = (
	authors     => 'tuqs',
	contact     => 'tuqs@core.ws',
	name        => 'youtube',
	description => 'shows the title and description from the video',
	license     => 'Public Domain',
	changed     => $VERSION,
);


#
# 20081105 - function rewrite
# 20081226 - fixed regex
# 20090206 - some further fixes
#
# usage:
# /script load youtube
# enjoy ;o)
#


sub htmlfix {
	my $s = shift;
	$s =~ s!&amp;!&!g;
	$s =~ s!&quot;!"!g;
	$s =~ s!&rsquo;!'!g;
	$s =~ s!&\#039;!'!g;
	$s =~ s!&ndash;!-!g;
	$s =~ s!&lt;!<!g;
	$s =~ s!&gt;!>!g;
	$s =~ s!</?br\s?/?>! !g;
	$s =~ s!\(<a.+>more</a>\)!!gi; # remove more
	$s =~ s!<a.+>.+</a>!!g; # remove links
	$s =~ s/\s+$//g; # last but not least remove tailing blanks
	return $s;
}

sub youtube {
	my ( $server, $msg, $nick, $addr, $target ) = @_;
	my $window = $server->window_find_item($target);
	if ($msg =~ /\.youtube\.com\/watch\?v=(.{11})/) {
		my $ua = LWP::UserAgent->new;
		my $r = $ua->get("http://m.youtube.com/details?v=$1&warned=1&hl=en");
		Irssi::signal_continue(@_);
		return unless defined $r;
		# yes i know, parsing html with regular expressions is stupid
		# but i want to keep the dependencies as minimal as possible
		$r->content =~ /<title>YouTube\s-\s(.+)<\/title>/;
		$window->command("echo ".chr(3)."14"."title:".chr(3)." ".htmlfix($1)) if defined $1;
		$r->content =~ /<div><b>Video\sDescription:<\/b><\/div>\n\s+<div><span\sstyle="font-size:small;">\n\s+(.+)\n\s+<\/span><\/div>\n<\/div>/;
		$window->command("echo ".chr(3)."14"."description:".chr(3)." ".htmlfix($1)) if defined $1;
	}
}

Irssi::signal_add_first('message public', \&youtube);
