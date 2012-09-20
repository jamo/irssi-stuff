# - The most difficult part is to determine what other people see your hostname is $server->{userhost} provided by irssi is not useful for this since it only
#   fills if you have joined channels, and then never updates, and might be your real hostname instead of the one other people see, and cannot be
#   changed from a perl script.
#
# - So for simplicity we just use the rfc2812 section 2.3.1 maximum of 63 characters for the hostname and the maximum of 10 for username (including a leading ~ on some networks) from anecdotal testing, since I couldn't find any "authoritative" information for username maximum length
#   hopefully ircds comply with this restriction; it's a little hard for me to test.
#
# - /msg #foo,bar,#baz is unsupported and will split the lines a little too
#   early (but won't ever cutoff or destroy your messages).

use strict;
use warnings;
use Irssi;

our $VERSION = "0.20.48";
our %IRSSI = (
  name        => "splitlong",
  description => "Split messages and actions to not exceed length allowed by ircds",
  url         => "http://scripts.irssi.org/scripts/splitlong.pl",
  authors     => "ferret",
  contact     => "ferret(tA)explodingferret(moCtoD), ferret on irc.freenode.net",
  origin      => "original author Bjoern 'fuchs' Krombholz, bjkro\@gmx.de",
  licence     => "Public Domain",
  changed     => "2008-07-06",
  changes     => <<'EOT',
0.20.48: remove redirects and aggressive tactics, use RFC mandated maximums instead
0.20.47: check winitem type for compatibility with other scripts
0.20.46: major cleanup
0.20.45: cleanup, remove 001 stuff, fix redirects
0.20.44: support /me, /msg -chatnet, aggressively get userhost
EOT
  modules     => "",
  commands    => "splitlong",
);

sub debug_print {
  Irssi::print "\%c$IRSSI{name}\%n: \%Rwarning2\%n: " . join( "\n  ", @_ ), MSGLEVEL_CLIENTERROR;
}
sub pretty_print {
  Irssi::print "\%c$IRSSI{name}\%n: " . join( "\n  ", @_ ), MSGLEVEL_CLIENTCRAP;
}

Irssi::settings_add_int 'splitlong', 'splitlong_safety_margin', 0;
Irssi::settings_add_str 'splitlong', 'splitlong_line_start',    "... ";
Irssi::settings_add_str 'splitlong', 'splitlong_line_end',      " ...";

# to get free tab completion
Irssi::command_bind 'splitlong'       => sub {
    pretty_print( "version $VERSION", $IRSSI{description}, <<'EOT' );

/set splitlong_safety_margin <integer>
  If you experience cutoff, you can set this to about how many characters get
  cut off and it should fix it. I'd rather you contacted me though.
  Default: 0 (recommended unless you have issues)

/set splitlong_line_start <string>
/set splitlong_line_end <string>
  Defaults: "... ", " ...".
EOT
};



# main splitting handler
Irssi::signal_add_first 'command msg'    => sub { sig_command_msg( @_, 'msg'    ); };
Irssi::signal_add_first 'command action' => sub { sig_command_msg( @_, 'action' ); };
Irssi::signal_add_first 'command me'     => sub { sig_command_msg( @_, 'me'     ); };
sub sig_command_msg {
  my ( $cmd, $server, $winitem, $action ) = @_;

  if( $cmd =~ s/^SPLIT_WITH_SPLITLONG// ) {
    # we must have split this already
    Irssi::signal_continue $cmd, $server, $winitem;
    return;
  }

  # From /help:
  #   MSG [-<server tag>] [-channel | -nick] <targets> <message>
  #   ACTION [-<server tag>] <target> <message>
 
  # Also note that /say does /msg * <message> and text entry in a channel or
  # query window does for e.g. /msg -channel "#channel" <message>
  my ( $param, $target, $data ) = $action eq 'me'
   ? ( '', '', $cmd )
   : $cmd =~ /^((?:-\S*\s)*)(\S*\s)(.*)/;

  return unless defined $data;

  my $real_server = $server;
  if( $param =~ /^-(\S*)/ ) {
    unless( $1 eq 'nick' or $1 eq 'channel') {
      $real_server = Irssi::server_find_tag $1;
    }
  }
  
  return unless $real_server && $real_server->{connected};

  # expected values of $target are:
  # '"#channel" ', '*', 'somenick', or '#chan'
  my( $real_target ) = $target =~ /^"?(.*?)"?\s?$/;
  if( $real_target eq '*' or $real_target eq '' ) {
    # it's a /say (which is really a /msg *) or a /me
    # they don't make sense outside of a channel or query
    return unless $winitem && $winitem->{name};
    return unless $winitem->{type} eq "CHANNEL" || $winitem->{type} eq "QUERY";
    $real_target = $winitem->{name};
  }

  my $safety = Irssi::settings_get_int 'splitlong_safety_margin';
  my $lstart = Irssi::settings_get_str 'splitlong_line_start';
  my $lend   = Irssi::settings_get_str 'splitlong_line_end';

  # :mynick!user@host PRIVMSG nick :message
  # 510 = 512 - length("\r\n") # 512 is mandated by rfc2812
  # 497 = 510 - length(":" . "!" . " PRIVMSG " . " :");
  # 423 = 497 - length("@" . $ownusername . $ownhostname) # maximum 63 for hostname, 10 for username
  #  leaving just the nick length and the target nick/channel's length
  my $maxlength = 422 - length( $real_server->{nick} . $real_target );

  # 9 = length( "\01ACTION " . $msg . "\01" ) - length( $msg );
  $maxlength -= 9 if $action eq 'me' || $action eq 'action';
  $maxlength -= $safety;
  my $maxlength2 = $maxlength - length( $lend );

  if ( length( $data ) > $maxlength ) {
    my ( $pos, $datachunk );

    while ( length( $data ) > $maxlength2 ) {
      $pos = rindex( $data, " ", $maxlength2 );
      # if the rightmost space ($pos) is more than 60 chars away fom the line
      # end, split mid-word instead
      $datachunk = substr( $data, 0, $pos < 60 ? $maxlength2 : $pos ) . $lend;

      # There's no way to stop this script from recapturing the signal we
      # need to emit here, so we 'mark' it to prevent it being processed twice
      Irssi::signal_emit "command $action", 'SPLIT_WITH_SPLITLONG' . $param . $target . $datachunk, $server, $winitem;

      $data = $lstart . substr( $data, $pos < 60 ? $maxlength2 : $pos + 1 );
    }
    
    Irssi::signal_continue $param . $target . $data, $server, $winitem;
  }
}

pretty_print( "version $VERSION loaded. For help: /splitlong" );
