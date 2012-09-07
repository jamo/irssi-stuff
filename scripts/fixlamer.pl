# lamerfix.pl by slug for splidge
# v1.10 - splidge changed replacements so brackets fit around all replaced text
# v1.20 - added NULL to remove items (like that useless acronym that the lamers james and r1ch4rd use: tbh)
# v1.30 - rewrite to fix crappy bugs
# v1.31 - fixed a few display issues
# v1.40 - now does grammer

my @lamewords_s = qw/i!SPACE!r  r   u   ur   teh i i've ive  i'm uve    b  urself   u've   tbh    tbfh   actually kewl 10q             y    yah k    nsfw ok   hdf                         jo hi    cya     kk   ty              y'all         cmon          c'mon         nah nope ^^     sup             kthx               np               nowai        thx    wtf                       wth                       idk                      dunno                    plz    i'll bye     i'd pls    atm                       hf             gl              hai   bai     ic          yea brb                       fu             luv  ofc             morn                hy    thnx   yw                   fyi                       nm             oi    imo                       imho                                   yep yup jep jup afk                            nö   nä   gtg                   oic                  gtfo                               haz hawt orly             yarly           rly    n8    gn8             nvm        sup?             ikr/; #search
my @lamewords_r = qw/I!SPACE!am are you your the I I've I've I'm you've be yourself you've !NULL! !NULL! !NULL!   cool thank!SPACE!you why᾽ yes okay NSFW okay bitte!SPACE!sei!SPACE!leise ja hello goodbye okay thank!SPACE!you you!SPACE!all come!SPACE!on come!SPACE!on no  no   !NULL! what's!SPACE!up okay,!SPACE!thanks no!SPACE!problem no!SPACE!way thanks what!SPACE!the!SPACE!fuck what!SPACE!the!SPACE!hell I!SPACE!don't!SPACE!know I!SPACE!don't!SPACE!know please I'll goodbye I'd please at!SPACE!the!SPACE!moment have!SPACE!fun good!SPACE!luck hello goodbye I!SPACE!see yes be!SPACE!right!SPACE!back fuck!SPACE!you love of!SPACE!course good!SPACE!morning  hello thanks you're!SPACE!welcome for!SPACE!your!SPACE!info not!SPACE!much hello in!SPACE!my!SPACE!opinion in!SPACE!my!SPACE!humble!SPACE!opinion yes yes yes yes away!SPACE!from!SPACE!keyboard nein nein got!SPACE!to!SPACE!go oh!SPACE!I!SPACE!see get!SPACE!the!SPACE!fuck!SPACE!out has hot  oh!SPACE!really yes!SPACE!really really nacht gute!SPACE!nacht nevermind what's!SPACE!up? I!SPACE!know,!SPACErite?/; #replace
my @lamewords_i = qw/0          0   0   0    0   1 1    0    1   0      0  0        0      0      0      0        0    0               1    0   0    0    0    0                           0  0     0       0    0               0             0             0             0   0    0      0               0                  0                0            0      0                         0                         0                        0                        0      1    0       1   0      1                         0              0               0     0       1           0  0                          0              0    0               0                   0     0      0                   0                          0              0     0                         0                                      0   0   0   0   0                              0    0    0                     0                    0                                  0   0    0               0                0      0     0                0         0                0/; #options (0 for case insensitive)

$lamer_bchar = chr(0); #impossible (hopefully!) irc characters
$lamer_echar = chr(10);
$lamer_lchar = chr(13);

{
  my $i = 0;
  for (@lamewords_r) {
    if ($_ eq "!NULL!") {
      $_ = "";
    } else {
      s/!SPACE!/ /g;
      s/^(.*)$/$lamer_bchar$1$lamer_echar/;
      $lamewords_s[$i] = lc($lamewords_s[$i]) if ($lamewords_i[$i] == 0);
    }
    $i++;
  }
}

sub pub_filter {
  my ($server, $data, $nick, $mask, $target) = @_;
  my $got;
#  my @cows = split / /, $data;
  my @cows;
  my $lastitem = "";
  for (0..length($data)-1) {
    my $citem = substr($data, $_, 1);
    if ($citem eq " ") {
      push @cows, $lastitem;
      $lastitem = "";
    } else {
      $lastitem .= $citem;
    }
  }
  push @cows, $lastitem if ($lastitem ne "");
  my $newcrap;
  my $j = 0;
  my $ignorenext = 0;
  for (@cows) {
    if ($ignorenext > 0) {
      $_ = "";
      $ignorenext--;
      $j++;
      next;
    }
    $_ = $lamer_lchar if ($_ eq "");
    my $i = 0;
    my $l = lc($_);
    for my $word (@lamewords_s) {
      if($_ ne $lamer_lchar) {
        if($lamewords_i[$i]) {
          $newcrap = $_;
        } else {
          $newcrap = $l;
        }
        if ($word =~ /!space!/) {
          my @words = split /!space!/, $word;
          my $gibberish = "";
          for my $ass ($j..$j+@words-1) {
            $gibberish .= $cows[$ass] . " ";
          }
          $gibberish =~ s/ $//;
          $gibberish = lc($gibberish) if(!$lamewords_i[$i]);
          if ($gibberish eq "@words") {
            $_ = $lamewords_r[$i];
            $ignorenext+=@words-1;
          }
        } elsif ($newcrap eq $word) {
          $_ = $lamewords_r[$i];
        }
      }
      $i++;
    }
    $j++;
  }

  my @newlist;

  for (@cows) {
    push @newlist, $_ if ($_ ne '');
  }

  Irssi::signal_stop();

  if (@newlist > 0) {
    $_ = "";
    for my $item (@newlist) {
      if ($item ne $lamer_lchar) {
        $_ .= $item . " ";
      } else {
        $_ .= " ";
      }
    }
    s/ $//s;
    while (s/$lamer_bchar ([^$lamer_echar]+) $lamer_echar \s+ $lamer_bchar ([^$lamer_echar]+) $lamer_echar /$lamer_bchar\1 \2$lamer_echar/xs) {};
    # ᾽
    s/${lamer_bchar}+//gs; #y/$lamer_bchar$lamer_echar/[]/; isn't working?!
    s/${lamer_echar}+//gs;
    Irssi::signal_remove('message public', 'pub_filter');
    Irssi::signal_emit('message public', $server, $_, $nick, $mask, $target);
    Irssi::signal_add_first('message public', 'pub_filter');
  }
}

Irssi::signal_add_last("message public", "pub_filter");
