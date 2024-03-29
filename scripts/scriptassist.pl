# by Stefan "tommie" Tomanek
#
# scriptassist.pl


use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '2003020803-r1';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek',
    contact     => 'stefan@pico.ruhr.de',
    name        => 'scriptassist',
    description => 'keeps your scripts on the cutting edge',
    license     => 'GPLv2',
    url         => 'http://irssi.org/scripts/',
    changed     => $VERSION,
    modules     => 'Data::Dumper LWP::UserAgent (GnuPG)',
    commands	=> "scriptassist"
);

use vars qw($forked %remote_db $have_gpg);

use Irssi 20020324;
use Data::Dumper;
use LWP::UserAgent;
use POSIX;

# GnuPG is not always needed
use vars qw($have_gpg @complist);
$have_gpg = 0;
eval "use GnuPG qw(:algo :trust);";
$have_gpg = 1 if not ($@);

sub show_help() {
    my $help = "scriptassist $VERSION
/scriptassist check
    Check all loaded scripts for new available versions
/scriptassist update <script|all>
    Update the selected or all script to the newest version
/scriptassist search <query>
    Search the script database
/scriptassist info <scripts>
    Display information about <scripts>
/scriptassist ratings <scripts>
    Retrieve the average ratings of the the scripts
/scriptassist top <num>
    Retrieve the first <num> top rated scripts
/scriptassist new <num>
    Display the newest <num> scripts
/scriptassist rate <script> <stars>
    Rate the script with a number of stars ranging from 0-5
/scriptassist contact <script>
    Write an email to the author of the script
    (Requires OpenURL)
/scriptassist cpan <module>
    Visit CPAN to look for missing Perl modules
    (Requires OpenURL)
/scriptassist install <script>
    Retrieve and load the script
/scriptassist autorun <script>
    Toggles automatic loading of <script>
";  
    my $text='';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box("ScriptAssist", $text, "scriptassist help", 1);
    #theme_box("ScriptAssist", $text, "scriptassist help", 1);
}

sub theme_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'box_header', $title);
    foreach (split(/\n/, $text)) {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'box_inside', $_);
    }
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'box_footer', $footer);
}

sub draw_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
        $box .= '%R|%n '.$_."\n";
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    return $box;
}

sub call_openurl ($) {
    my ($url) = @_;
    no strict "refs";
    # check for a loaded openurl
    if (%{ "Irssi::Script::openurl::" }) {
        &{ "Irssi::Script::openurl::launch_url" }($url);
    } else {
        print CLIENTCRAP "%R>>%n Please install openurl.pl";
    }
    use strict;
}

sub bg_do ($) {
    my ($func) = @_; 
    my ($rh, $wh);
    pipe($rh, $wh);
    if ($forked) {
	print CLIENTCRAP "%R>>%n Please wait until your earlier request has been finished.";
	return;
    }
    my $pid = fork();
    $forked = 1;
    if ($pid > 0) {
	print CLIENTCRAP "%R>>%n Please wait...";
        close $wh;
        Irssi::pidwait_add($pid);
        my $pipetag;
        my @args = ($rh, \$pipetag, $func);
        $pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	eval {
	    my @items = split(/ /, $func);
	    my %result;
	    my $ts1 = $remote_db{timestamp};
	    my $xml = get_scripts();
	    my $ts2 = $remote_db{timestamp};
	    if (not($ts1 eq $ts2) && Irssi::settings_get_bool('scriptassist_cache_sources')) {
		$result{db} = $remote_db{db};
		$result{timestamp} = $remote_db{timestamp};
	    }
	    if ($items[0] eq 'check') {
		$result{data}{check} = check_scripts($xml);
	    } elsif ($items[0] eq 'update') {
		shift(@items);
		$result{data}{update} = update_scripts(\@items, $xml);
	    } elsif ($items[0] eq 'search') {
		shift(@items);
		#$result{data}{search}{-foo} = 0;
		foreach (@items) {
		    $result{data}{search}{$_} = search_scripts($_, $xml);
		}
	    } elsif ($items[0] eq 'install') {
		shift(@items);
		$result{data}{install} = install_scripts(\@items, $xml);
	    } elsif ($items[0] eq 'debug') {
		shift(@items);
		$result{data}{debug} = debug_scripts(\@items);
	    } elsif ($items[0] eq 'ratings') {
		shift(@items);
		@items = @{ loaded_scripts() } if $items[0] eq "all";
		#$result{data}{rating}{-foo} = 1;
		my %ratings = %{ get_ratings(\@items, '') };
		foreach (keys %ratings) {
		    $result{data}{rating}{$_}{rating} = $ratings{$_}->[0];
		    $result{data}{rating}{$_}{votes} = $ratings{$_}->[1];
		}
	    } elsif ($items[0] eq 'rate') {
		#$result{data}{rate}{-foo} = 1;
		$result{data}{rate}{$items[1]} = rate_script($items[1], $items[2]);
	    } elsif ($items[0] eq 'info') {
		shift(@items);
		$result{data}{info} = script_info(\@items);
	    } elsif ($items[0] eq 'echo') {
		$result{data}{echo} = 1;
	    } elsif ($items[0] eq 'top') {
		my %ratings = %{ get_ratings([], $items[1]) };
		foreach (keys %ratings) {
                    $result{data}{rating}{$_}{rating} = $ratings{$_}->[0];
                    $result{data}{rating}{$_}{votes} = $ratings{$_}->[1];
                }
	    } elsif ($items[0] eq 'new') {
		my $new = get_new($items[1]);
		$result{data}{new} = $new;
	    } elsif ($items[0] eq 'unknown') {
		my $cmd = $items[1];
		$result{data}{unknown}{$cmd} = get_unknown($cmd, $xml);
	    }
	    my $dumper = Data::Dumper->new([\%result]);
	    $dumper->Purity(1)->Deepcopy(1)->Indent(0);
	    my $data = $dumper->Dump;
	    print($wh $data);
	};
	close($wh);
	POSIX::_exit(1);
    }
}

sub get_unknown ($$) {
    my ($cmd, $db) = @_;
    foreach (keys %$db) {
	next unless defined $db->{$_}{commands};
	foreach my $item (split / /, $db->{$_}{commands}) {
	    return { $_ => $db->{$_} } if ($item =~ /^$cmd$/i);
	}
    }
    return undef;
}

sub script_info ($) {
    my ($scripts) = @_;
    no strict "refs";
    my %result;
    my $xml = get_scripts();
    foreach (@{$scripts}) {
	next unless (defined $xml->{$_.".pl"} || (%{ 'Irssi::Script::'.$_.'::' } && %{ 'Irssi::Script::'.$_.'::IRSSI' }));
	$result{$_}{version} = get_remote_version($_, $xml);
	my @headers = ('authors', 'contact', 'description', 'license', 'source');
	foreach my $entry (@headers) {
	    $result{$_}{$entry} = ${ 'Irssi::Script::'.$_.'::IRSSI' }{$entry};
	    if (defined $xml->{$_.".pl"}{$entry}) {
		$result{$_}{$entry} = $xml->{$_.".pl"}{$entry};
	    }
	}
	if ($xml->{$_.".pl"}{signature_available}) {
	    $result{$_}{signature_available} = 1;
	}
	if (defined $xml->{$_.".pl"}{modules}) {
	    my $modules = $xml->{$_.".pl"}{modules};
	    #$result{$_}{modules}{-foo} = 1;
	    foreach my $mod (split(/ /, $modules)) {
		my $opt = ($mod =~ /\((.*)\)/)? 1 : 0;
		$mod = $1 if $1;
		$result{$_}{modules}{$mod}{optional} = $opt;
		$result{$_}{modules}{$mod}{installed} = module_exist($mod);
	    }
	} elsif (defined ${ 'Irssi::Script::'.$_.'::IRSSI' }{modules}) {
	    my $modules = ${ 'Irssi::Script::'.$_.'::IRSSI' }{modules};
	    foreach my $mod (split(/ /, $modules)) {
		my $opt = ($mod =~ /\((.*)\)/)? 1 : 0;
		$mod = $1 if $1;
		$result{$_}{modules}{$mod}{optional} = $opt;
		$result{$_}{modules}{$mod}{installed} = module_exist($mod);
	    }
	}
	if (defined $xml->{$_.".pl"}{depends}) {
	    my $depends = $xml->{$_.".pl"}{depends};
	    foreach my $dep (split(/ /, $depends)) {
		$result{$_}{depends}{$dep}{installed} = 1; #(defined ${ 'Irssi::Script::'.$dep }); 
	    }
	}
    }
    return \%result;
}

sub rate_script ($$) {
    my ($script, $stars) = @_;
    my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>30);
    $ua->agent('ScriptAssist/'.$VERSION);
    my $request = HTTP::Request->new('GET', 'http://ratings.irssi.de/irssirate.pl?&stars='.$stars.'&mode=rate&script='.$script);
    my $response = $ua->request($request);
    unless ($response->is_success() && $response->content() =~ /You already rated this script/) {
	return 1;
    } else {
	return 0;
    }
}

sub get_ratings ($$) {
    my ($scripts, $limit) = @_;
    my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>30);
    $ua->agent('ScriptAssist/'.$VERSION);
    my $script = join(',', @{$scripts});
    my $request = HTTP::Request->new('GET', 'http://ratings.irssi.de/irssirate.pl?script='.$script.'&sort=rating&limit='.$limit);
    my $response = $ua->request($request);
    my %result;
    if ($response->is_success()) {
	foreach (split /\n/, $response->content()) {
	    if (/<tr><td><a href=".*?">(.*?)<\/a>/) {
		my $entry = $1;
		if (/"><\/td><td>([0-9.]+)<\/td><td>(.*?)<\/td><td>/) {
		    $result{$entry} = [$1, $2];
		}
	    }
	}
    }
    return \%result;
}

sub get_new ($) {
    my ($num) = @_;
    my $result;
    my $xml = get_scripts();
    foreach (sort {$xml->{$b}{last_modified} cmp $xml->{$a}{last_modified}} keys %$xml) {
	my %entry = %{ $xml->{$_} };
	$result->{$_} = \%entry;
	$num--;
	last unless $num;
    }
    return $result;
}
sub module_exist ($) {
    my ($module) = @_;
    $module =~ s/::/\//g;
    foreach (@INC) {
	return 1 if (-e $_."/".$module.".pm");
    }
    return 0;
}

sub debug_scripts ($) {
    my ($scripts) = @_;
    my %result;
    foreach (@{$scripts}) {
	my $xml = get_scripts();
	if (defined $xml->{$_.".pl"}{modules}) {
	    my $modules = $xml->{$_.".pl"}{modules};
	    foreach my $mod (split(/ /, $modules)) {
                my $opt = ($mod =~ /\((.*)\)/)? 1 : 0;
                $mod = $1 if $1;
                $result{$_}{$mod}{optional} = $opt;
                $result{$_}{$mod}{installed} = module_exist($mod);
	    }
	}
    }
    return(\%result);
}

sub install_scripts ($$) {
    my ($scripts, $xml) = @_;
    my %success;
    #$success{-foo} = 1;
    my $dir = Irssi::get_irssi_dir()."/scripts/";
    foreach (@{$scripts}) {
	if (get_local_version($_) && (-e $dir.$_.".pl")) {
	    $success{$_}{installed} = -2;
	} else {
	    $success{$_} = download_script($_, $xml);
	}
    }
    return \%success;
}

sub update_scripts ($$) {
    my ($list, $database) = @_;
    $list = loaded_scripts() if ($list->[0] eq "all" || scalar(@$list) == 0);
    my %status;
    #$status{-foo} = 1;
    foreach (@{$list}) {
	my $local = get_local_version($_);
	my $remote = get_remote_version($_, $database);
	next if $local eq '' || $remote eq '';
	if (compare_versions($local, $remote) eq "older") {
	    $status{$_} = download_script($_, $database);
	} else {
	    $status{$_}{installed} = -2;
	}
	$status{$_}{remote} = $remote;
	$status{$_}{local} = $local;
    }
    return \%status;
}

sub search_scripts ($$) {
    my ($query, $database) = @_;
    my %result;
    #$result{-foo} = " ";
    foreach (sort keys %{$database}) {
	my %entry = %{$database->{$_}};
	my $string = $_." ";
	$string .= $entry{description} if defined $entry{description};
	if ($string =~ /$query/i) {
	    my $name = $_;
	    $name =~ s/\.pl$//;
	    if (defined $entry{description}) {
		$result{$name}{desc} = $entry{description};
	    } else {
		$result{$name}{desc} = "";
	    }
	    if (defined $entry{authors}) {
		$result{$name}{authors} = $entry{authors};
	    } else {
		$result{$name}{authors} = "";
	    }
	    if (get_local_version($name)) {
		$result{$name}{installed} = 1;
	    } else {
		$result{$name}{installed} = 0;
	    }
	}
    }
    return \%result;
}

sub pipe_input {
    my ($rh, $pipetag) = @{$_[0]};
    my @lines = <$rh>;
    close($rh);
    Irssi::input_remove($$pipetag);
    $forked = 0;
    my $text = join("", @lines);
    unless ($text) {
	print CLIENTCRAP "%R<<%n Something weird happend";
	return();
    }
    no strict "vars";
    my $incoming = eval("$text");
    if ($incoming->{db} && $incoming->{timestamp}) {
    	$remote_db{db} = $incoming->{db};
    	$remote_db{timestamp} = $incoming->{timestamp};
    }
    unless (defined $incoming->{data}) {
	print CLIENTCRAP "%R<<%n Something weird happend";
	return;
    }
    my %result = %{ $incoming->{data} };
    @complist = ();
    if (defined $result{new}) {
	print_new($result{new});
	push @complist, $_ foreach keys %{ $result{new} };
    }
    if (defined $result{check}) {
	print_check(%{$result{check}});
	push @complist, $_ foreach keys %{ $result{check} };
    }
    if (defined $result{update}) {
	print_update(%{ $result{update} });
	push @complist, $_ foreach keys %{ $result{update} };
    }
    if (defined $result{search}) {
	foreach (keys %{$result{search}}) {
	    print_search($_, %{$result{search}{$_}});
	    push @complist, keys(%{$result{search}{$_}});
	}
    }
    if (defined $result{install}) {
	print_install(%{ $result{install} });
	push @complist, $_ foreach keys %{ $result{install} };
    }
    if (defined $result{debug}) {
	print_debug(%{ $result{debug} });
    }
    if (defined $result{rating}) {
	print_ratings(%{ $result{rating} });
	push @complist, $_ foreach keys %{ $result{rating} };
    }
    if (defined $result{rate}) {
	print_rate(%{ $result{rate} });
    }
    if (defined $result{info}) {
	print_info(%{ $result{info} });
    }
    if (defined $result{echo}) {
	Irssi::print "ECHO";
    }
    if ($result{unknown}) {
        print_unknown($result{unknown});
    }

}

sub print_unknown ($) {
    my ($data) = @_;
    foreach my $cmd (keys %$data) {
	print CLIENTCRAP "%R<<%n No script provides '/$cmd'" unless $data->{$cmd};
	foreach (keys %{ $data->{$cmd} }) {
	    my $text .= "The command '/".$cmd."' is provided by the script '".$data->{$cmd}{$_}{name}."'.\n";
	    $text .= "This script is currently not installed on your system.\n";
	    $text .= "If you want to install the script, enter\n";
	    my ($name) = /(.*?)\.pl$/;
	    $text .= "  %U/script install ".$name."%U ";
	    my $output = draw_box("ScriptAssist", $text, "'".$_."' missing", 1);
	    print CLIENTCRAP $output;
	}
    }
}

sub check_autorun ($) {
    my ($script) = @_;
    my $dir = Irssi::get_irssi_dir()."/scripts/";
    if (-e $dir."/autorun/".$script.".pl") {
	if (readlink($dir."/autorun/".$script.".pl") eq "../".$script.".pl") {
	    return 1;
	}
    }
    return 0;
}

sub array2table {
    my (@array) = @_;
    my @width;
    foreach my $line (@array) {
        for (0..scalar(@$line)-1) {
            my $l = $line->[$_];
            $l =~ s/%[^%]//g;
            $l =~ s/%%/%/g;
            $width[$_] = length($l) if $width[$_]<length($l);
        }
    }   
    my $text;
    foreach my $line (@array) {
        for (0..scalar(@$line)-1) {
            my $l = $line->[$_];
            $text .= $line->[$_];
            $l =~ s/%[^%]//g;
            $l =~ s/%%/%/g;
            $text .= " "x($width[$_]-length($l)+1) unless ($_ == scalar(@$line)-1);
        }
        $text .= "\n";
    }
    return $text;
}


sub print_info (%) {
    my (%data) = @_;
    my $line;
    foreach my $script (sort keys(%data)) {
	my ($local, $autorun);
	if (get_local_version($script)) {
	    $line .= "%go%n ";
	    $local = get_local_version($script);
	} else {
	    $line .= "%ro%n ";
	    $local = undef;
	}
	if (defined $local || check_autorun($script)) {
	    $autorun = "no";
	    $autorun = "yes" if check_autorun($script);
	} else {
	    $autorun = undef;
	}
	$line .= "%9".$script."%9\n";
	$line .= "  Version    : ".$data{$script}{version}."\n";
	$line .= "  Source     : ".$data{$script}{source}."\n";
	$line .= "  Installed  : ".$local."\n" if defined $local;
	$line .= "  Autorun    : ".$autorun."\n" if defined $autorun;
	$line .= "  Authors    : ".$data{$script}{authors};
	$line .= " %Go-m signed%n" if $data{$script}{signature_available};
	$line .= "\n";
	$line .= "  Contact    : ".$data{$script}{contact}."\n";
	$line .= "  Description: ".$data{$script}{description}."\n";
	$line .= "\n" if $data{$script}{modules};
	$line .= "  Needed Perl modules:\n" if $data{$script}{modules};

        foreach (sort keys %{$data{$script}{modules}}) {
            if ( $data{$script}{modules}{$_}{installed} == 1 ) {
                $line .= "  %g->%n ".$_." (found)";
            } else {
                $line .= "  %r->%n ".$_." (not found)";
            }
	    $line .= " <optional>" if $data{$script}{modules}{$_}{optional};
            $line .= "\n";
        }
	#$line .= "  Needed Irssi scripts:\n";
	$line .= "  Needed Irssi Scripts:\n" if $data{$script}{depends};
	foreach (sort keys %{$data{$script}{depends}}) {
	    if ( $data{$script}{depends}{$_}{installed} == 1 ) {
		$line .= "  %g->%n ".$_." (loaded)";
	    } else {
		$line .= "  %r->%n ".$_." (not loaded)";
	    }
	    #$line .= " <optional>" if $data{$script}{depends}{$_}{optional};
	    $line .= "\n";
	}
    }
    print CLIENTCRAP draw_box('ScriptAssist', $line, 'info', 1) ;
}

sub print_rate (%) {
    my (%data) = @_;
    my $line;
    foreach my $script (sort keys(%data)) {
	if ($data{$script}) {
            $line .= "%go%n %9".$script."%9 has been rated";
        } else {
            $line .= "%ro%n %9".$script."%9 : Already rated this script";
        }
    }
    print CLIENTCRAP draw_box('ScriptAssist', $line, 'rating', 1) ;
}

sub print_ratings (%) {
    my (%data) = @_;
    my @table;
    foreach my $script (sort {$data{$b}{rating}<=>$data{$a}{rating}} keys(%data)) {
	my @line;
	if (get_local_version($script)) {
	    push @line, "%go%n";
	} else {
	    push @line, "%yo%n";
	}
        push @line, "%9".$script."%9";
	push @line, $data{$script}{rating};
	push @line, "[".$data{$script}{votes}." votes]";
	push @table, \@line;
    }
    print CLIENTCRAP draw_box('ScriptAssist', array2table(@table), 'ratings', 1) ;
}

sub print_new ($) {
    my ($list) = @_;
    my @table;
    foreach (sort {$list->{$b}{last_modified} cmp $list->{$a}{last_modified}} keys %$list) {
	my @line;
	my ($name) = /^(.*?)\.pl$/;
        if (get_local_version($name)) {
            push @line, "%go%n";
        } else {
            push @line, "%yo%n";
        }
	push @line, "%9".$name."%9";
	push @line, $list->{$_}{last_modified};
	push @table, \@line;
    }
    print CLIENTCRAP draw_box('ScriptAssist', array2table(@table), 'new scripts', 1) ;
}

sub print_debug (%) {
    my (%data) = @_;
    my $line;
    foreach my $script (sort keys %data) {
	$line .= "%ro%n %9".$script."%9 failed to load\n";
	$line .= "  Make sure you have the following perl modules installed:\n";
	foreach (sort keys %{$data{$script}}) {
	    if ( $data{$script}{$_}{installed} == 1 ) {
		$line .= "  %g->%n ".$_." (found)";
	    } else {
		$line .= "  %r->%n ".$_." (not found)\n";
		$line .= "     [This module is optional]\n" if $data{$script}{$_}{optional};
		$line .= "     [Try /scriptassist cpan ".$_."]";
	    }
	    $line .= "\n";
	}
	print CLIENTCRAP draw_box('ScriptAssist', $line, 'debug', 1) ;
    }
}

sub load_script ($) {
    my ($script) = @_;
    Irssi::command('script load '.$script);
}

sub print_install (%) {
    my (%data) = @_;
    my $text;
    my ($crashed, @installed);
    foreach my $script (sort keys %data) {
	my $line;
	if ($data{$script}{installed} == 1) {
	    my $hacked;
	    if ($have_gpg && Irssi::settings_get_bool('scriptassist_use_gpg')) {
		if ($data{$script}{signed} >= 0) {
		    load_script($script) unless (lc($script) eq lc($IRSSI{name}));
		} else {
		    $hacked = 1;
		}
	    } else {
		load_script($script) unless (lc($script) eq lc($IRSSI{name}));
	    }
    	    if (get_local_version($script) && not lc($script) eq lc($IRSSI{name})) {
		$line .= "%go%n %9".$script."%9 installed\n";
		push @installed, $script;
	    } elsif (lc($script) eq lc($IRSSI{name})) {
		$line .= "%yo%n %9".$script."%9 installed, please reload manually\n";
	    } else {
    		$line .= "%Ro%n %9".$script."%9 fetched, but unable to load\n";
		$crashed .= $script." " unless $hacked;
	    }
	    if ($have_gpg && Irssi::settings_get_bool('scriptassist_use_gpg')) {
		foreach (split /\n/, check_sig($data{$script})) {
		    $line .= "  ".$_."\n";
		}
	    }
	} elsif ($data{$script}{installed} == -2) {
	    $line .= "%ro%n %9".$script."%9 already loaded, please try \"update\"\n";
	} elsif ($data{$script}{installed} <= 0) {
	    $line .= "%ro%n %9".$script."%9 not installed\n";
    	    foreach (split /\n/, check_sig($data{$script})) {
		$line .= "  ".$_."\n";
	    }
	} else {
	    $line .= "%Ro%n %9".$script."%9 not found on server\n";
	}
	$text .= $line;
    }
    # Inspect crashed scripts
    bg_do("debug ".$crashed) if $crashed;
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'install', 1);
    list_sbitems(\@installed);
}

sub list_sbitems ($) {
    my ($scripts) = @_;
    my $text;
    foreach (@$scripts) {
	no strict 'refs';
	next unless %{ "Irssi::Script::${_}::" };
	next unless %{ "Irssi::Script::${_}::IRSSI" };
	my %header = %{ "Irssi::Script::${_}::IRSSI" };
	next unless $header{sbitems};
	$text .= '%9"'.$_.'"%9 provides the following statusbar item(s):'."\n";
	$text .= '  ->'.$_."\n" foreach (split / /, $header{sbitems});
    }
    return unless $text;
    $text .= "\n";
    $text .= "Enter '/statusbar window add <item>' to add an item.";
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'sbitems', 1);
}

sub check_sig ($) {
    my ($sig) = @_;
    my $line;
    my %trust = ( -1 => 'undefined',
                   0 => 'never',
		   1 => 'marginal',
		   2 => 'fully',
		   3 => 'ultimate'
		 );
    if ($sig->{signed} == 1) {
	$line .= "Signature found from ".$sig->{sig}{user}."\n";
	$line .= "Timestamp  : ".$sig->{sig}{date}."\n";
	$line .= "Fingerprint: ".$sig->{sig}{fingerprint}."\n";
	$line .= "KeyID      : ".$sig->{sig}{keyid}."\n";
	$line .= "Trust      : ".$trust{$sig->{sig}{trust}}."\n";
    } elsif ($sig->{signed} == -1) {
	$line .= "%1Warning, unable to verify signature%n\n";
    } elsif ($sig->{signed} == 0) {
	$line .= "%1No signature found%n\n" unless Irssi::settings_get_bool('scriptassist_install_unsigned_scripts');
    }
    return $line;
}

sub print_search ($%) {
    my ($query, %data) = @_;
    my $text;
    foreach (sort keys %data) {
	my $line;
	$line .= "%go%n" if $data{$_}{installed};
	$line .= "%yo%n" if not $data{$_}{installed};
	$line .= " %9".$_."%9 ";
	$line .= $data{$_}{desc};
	$line =~ s/($query)/%U$1%U/gi;
	$line .= ' ('.$data{$_}{authors}.')';
	$text .= $line." \n";
    }
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'search: '.$query, 1) ;
}

sub print_update (%) { 
    my (%data) = @_;
    my $text;
    my @table;
    my $verbose = Irssi::settings_get_bool('scriptassist_update_verbose');
    foreach (sort keys %data) {
	my $signed = 0;
	if ($data{$_}{installed} == 1) {
	    my $local = $data{$_}{local};
	    my $remote = $data{$_}{remote};
	    push @table, ['%yo%n', '%9'.$_.'%9', 'upgraded ('.$local.'->'.$remote.')'];
	    foreach (split /\n/, check_sig($data{$_})) {
		push @table, ['', '', $_];
	    }
	    if (lc($_) eq lc($IRSSI{name})) {
		push @table, ['', '', "%R%9Please reload manually%9%n"];
	    } else {
		load_script($_);
	    }
	} elsif ($data{$_}{installed} == 0 || $data{$_}{installed} == -1) {
	    push @table, ['%yo%n', '%9'.$_.'%9', 'not upgraded'];
            foreach (split /\n/, check_sig($data{$_})) {
		push @table, ['', '', $_];
            } 
	} elsif ($data{$_}{installed} == -2 && $verbose) {
	    my $local = $data{$_}{local};
	    push @table, ['%go%n', '%9'.$_.'%9', 'already at the latest version ('.$local.')'];
    	}
    }
    $text = array2table(@table);
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'update', 1) ;
}

sub contact_author ($) {
    my ($script) = @_;
    no strict 'refs';
    return unless %{ "Irssi::Script::${script}::" };
    my %header = %{ "Irssi::Script::${script}::IRSSI" };
    if (defined $header{contact}) {
	my @ads = split(/ |,/, $header{contact});
	my $address = $ads[0];
	$address .= '?subject='.$script;
	$address .= '_'.get_local_version($script) if defined get_local_version($script);
	call_openurl($address);
    }
}

sub get_scripts {
    my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>30);
    $ua->agent('ScriptAssist/'.$VERSION);
    $ua->env_proxy();
    my @mirrors = split(/ /, Irssi::settings_get_str('scriptassist_script_sources'));
    my %sites_db;
    my $fetched = 0;
    my @sources;
    foreach my $site (@mirrors) {
	my $request = HTTP::Request->new('GET', $site);
	if ($remote_db{timestamp}) {
	    $request->if_modified_since($remote_db{timestamp});
	}
	my $response = $ua->request($request);
	next unless $response->is_success;
	$fetched = 1;
	my $data = $response->content();
	my ($src, $type);
	if ($site =~ /(.*\/).+\.(.+)/) {
	    $src = $1;
	    $type = $2;
	}
	push @sources, $src;
	#my @header = ('name', 'contact', 'authors', 'description', 'version', 'modules', 'last_modified');
	if ($type eq 'dmp') {
	    no strict 'vars';
	    my $new_db = eval "$data";
	    foreach (keys %$new_db) {
		if (defined $sites_db{script}{$_}) {
		    my $old = $sites_db{$_}{version};
		    my $new = $new_db->{$_}{version};
		    next if (compare_versions($old, $new) eq 'newer');
		}
		#foreach my $key (@header) {
		foreach my $key (keys %{ $new_db->{$_} }) {
		    next unless defined $new_db->{$_}{$key};
		    $sites_db{$_}{$key} = $new_db->{$_}{$key};
		}
		$sites_db{$_}{source} = $src;
	    }
	} else {
	    ## FIXME Panic?!
	}
	
    }
    if ($fetched) {
	# Clean database
	foreach (keys %{$remote_db{db}}) {
	    foreach my $site (@sources) {
		if ($remote_db{db}{$_}{source} eq $site) {
		    delete $remote_db{db}{$_};
		    last;
		}
	    }
	}
	$remote_db{db}{$_} = $sites_db{$_} foreach (keys %sites_db);
	$remote_db{timestamp} = time();
    }
    return $remote_db{db};
}

sub get_remote_version ($$) {
    my ($script, $database) = @_;
    return $database->{$script.".pl"}{version};
}

sub get_local_version ($) {
    my ($script) = @_;
    no strict 'refs';
    return unless %{ "Irssi::Script::${script}::" };
    my $version = ${ "Irssi::Script::${script}::VERSION" };
    return $version;
}

sub compare_versions ($$) {
    my ($ver1, $ver2) = @_;
    my @ver1 = split /\./, $ver1;
    my @ver2 = split /\./, $ver2;
    #if (scalar(@ver2) != scalar(@ver1)) {
    #    return 0;
    #}       
    my $cmp = 0;
    ### Special thanks to Clemens Heidinger
    $cmp ||= $ver1[$_] <=> $ver2[$_] || $ver1[$_] cmp $ver2[$_] for 0..scalar(@ver2);
    return 'newer' if $cmp == 1;
    return 'older' if $cmp == -1;
    return 'equal';
}

sub loaded_scripts {
    no strict 'refs';
    my @modules;
    foreach (sort grep(s/::$//, keys %Irssi::Script::)) {
        #my $name    = ${ "Irssi::Script::${_}::IRSSI" }{name};
        #my $version = ${ "Irssi::Script::${_}::VERSION" };
	push @modules, $_;# if $name && $version;
    }
    return \@modules;

}

sub check_scripts {
    my ($data) = @_;
    my %versions;
    #$versions{-foo} = 1;
    foreach (@{loaded_scripts()}) {
        my $remote = get_remote_version($_, $data);
        my $local =  get_local_version($_);
	my $state;
	if ($local && $remote) {
	    $state = compare_versions($local, $remote);
	} elsif ($local) {
	    $state = 'noversion';
	    $remote = '/';
	} else {
	    $state = 'noheader';
	    $local = '/';
	    $remote = '/';
	}
	if ($state) {
	    $versions{$_}{state} = $state;
	    $versions{$_}{remote} = $remote;
	    $versions{$_}{local} = $local;
	}
    }
    return \%versions;
}

sub download_script ($$) {
    my ($script, $xml) = @_;
    my %result;
    my $site = $xml->{$script.".pl"}{source};
    $result{installed} = 0;
    $result{signed} = 0;
    my $dir = Irssi::get_irssi_dir();
    my $ua = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1,timeout => 30);
    $ua->agent('ScriptAssist/'.$VERSION);
    my $request = HTTP::Request->new('GET', $site.'/scripts/'.$script.'.pl');
    my $response = $ua->request($request);
    if ($response->is_success()) {
	my $file = $response->content();
	mkdir $dir.'/scripts/' unless (-e $dir.'/scripts/');
	local *F;
	open(F, '>'.$dir.'/scripts/'.$script.'.pl.new');
	print F $file;
	close(F);
	if ($have_gpg && Irssi::settings_get_bool('scriptassist_use_gpg')) {
	    my $ua2 = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1,timeout => 30);
	    $ua->agent('ScriptAssist/'.$VERSION);
	    my $request2 = HTTP::Request->new('GET', $site.'/signatures/'.$script.'.pl.asc');
	    my $response2 = $ua->request($request2);
	    if ($response2->is_success()) {
		local *S;
		my $sig_dir = $dir.'/scripts/signatures/';
		mkdir $sig_dir unless (-e $sig_dir);
		open(S, '>'.$sig_dir.$script.'.pl.asc');
		my $file2 = $response2->content();
		print S $file2;
		close(S);
		my $sig;
		foreach (1..2) {
		    # FIXME gpg needs two rounds to load the key
		    my $gpg = new GnuPG();
		    eval {
			$sig = $gpg->verify( file => $dir.'/scripts/'.$script.'.pl.new', signature => $sig_dir.$script.'.pl.asc' );
		    };
		}
		if (defined $sig->{user}) {
		    $result{installed} = 1;
		    $result{signed} = 1;
		    $result{sig}{$_} = $sig->{$_} foreach (keys %{$sig});
		} else {
		    # Signature broken?
		    $result{installed} = 0;
		    $result{signed} = -1;
		}
	    } else {
		$result{signed} = 0;
		$result{installed} = -1;
		$result{installed} = 1 if Irssi::settings_get_bool('scriptassist_install_unsigned_scripts');
	    }
	} else {
	    $result{signed} = 0;
	    $result{installed} = -1;
	    $result{installed} = 1 if Irssi::settings_get_bool('scriptassist_install_unsigned_scripts');
	}
    }
    if ($result{installed}) {
	my $old_dir = "$dir/scripts/old/";
	mkdir $old_dir unless (-e $old_dir);
	rename "$dir/scripts/$script.pl", "$old_dir/$script.pl.old" if -e "$dir/scripts/$script.pl";
	rename "$dir/scripts/$script.pl.new", "$dir/scripts/$script.pl";
    }
    return \%result;
}

sub print_check (%) {
    my (%data) = @_;
    my $text;
    my @table;
    foreach (sort keys %data) {
	my $state = $data{$_}{state};
	my $remote = $data{$_}{remote};
	my $local = $data{$_}{local};
	if (Irssi::settings_get_bool('scriptassist_check_verbose')) {
	    push @table, ['%go%n', '%9'.$_.'%9', 'Up to date. ('.$local.')'] if $state eq 'equal';
	}
	push @table, ['%mo%n', '%9'.$_.'%9', "No version information available on network."] if $state eq "noversion";
	push @table, ['%mo%n', '%9'.$_.'%9', 'No header in script.'] if $state eq "noheader";
	push @table, ['%bo%n', '%9'.$_.'%9', "Your version is newer (".$local."->".$remote.")"] if $state eq "newer";
	push @table, ['%ro%n', '%9'.$_.'%9', "A new version is available (".$local."->".$remote.")"] if $state eq "older";;
    }
    $text = array2table(@table);
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'check', 1) ;
}

sub toggle_autorun ($) {
    my ($script) = @_;
    my $dir = Irssi::get_irssi_dir()."/scripts/";
    mkdir $dir."autorun/" unless (-e $dir."autorun/");
    return unless (-e $dir.$script.".pl");
    if (check_autorun($script)) {
	if (readlink($dir."/autorun/".$script.".pl") eq "../".$script.".pl") {
	    if (unlink($dir."/autorun/".$script.".pl")) {
		print CLIENTCRAP "%R>>%n Autorun of ".$script." disabled";
	    } else {
		print CLIENTCRAP "%R>>%n Unable to delete link";
	    }
	} else {
	    print CLIENTCRAP "%R>>%n ".$dir."/autorun/".$script.".pl is not a correct link";
	}
    } else {
	symlink("../".$script.".pl", $dir."/autorun/".$script.".pl");
    	print CLIENTCRAP "%R>>%n Autorun of ".$script." enabled";
    }
}

sub sig_script_error ($$) {
    my ($script, $msg) = @_;
    return unless Irssi::settings_get_bool('scriptassist_catch_script_errors');
    if ($msg =~ /Can't locate (.*?)\.pm in \@INC \(\@INC contains:(.*?) at/) {
        my $module = $1;
        $module =~ s/\//::/g;
	missing_module($module);
    }
}

sub missing_module ($$) {
    my ($module) = @_;
    my $text;
    $text .= "The perl module %9".$module."%9 is missing on your system.\n";
    $text .= "Please ask your administrator about it.\n";
    $text .= "You can also check CPAN via '/scriptassist cpan ".$module."'.\n";
    print CLIENTCRAP &draw_box('ScriptAssist', $text, $module, 1);
}

sub cmd_scripassist ($$$) {
    my ($arg, $server, $witem) = @_;
    my @args = split(/ /, $arg);
    if ($args[0] eq 'help' || $args[0] eq '-h') {
	show_help();
    } elsif ($args[0] eq 'check') {
	bg_do("check");
    } elsif ($args[0] eq 'update') {
	shift @args;
	bg_do("update ".join(' ', @args));
    } elsif ($args[0] eq 'search' && defined $args[1]) {
	shift @args;
	bg_do("search ".join(" ", @args));
    } elsif ($args[0] eq 'install' && defined $args[1]) {
	shift @args;
	bg_do("install ".join(' ', @args));
    } elsif ($args[0] eq 'contact' && defined $args[1]) {
	contact_author($args[1]);
    } elsif ($args[0] eq 'ratings' && defined $args[1]) {
	shift @args;
	bg_do("ratings ".join(' ', @args));
    } elsif ($args[0] eq 'rate' && defined $args[1] && defined $args[2]) {
	shift @args;
	bg_do("rate ".join(' ', @args)) if ($args[2] >= 0 && $args[2] < 6);
    } elsif ($args[0] eq 'info' && defined $args[1]) {
	shift @args;
	bg_do("info ".join(' ', @args));
    } elsif ($args[0] eq 'echo') {
	bg_do("echo");
    } elsif ($args[0] eq 'top') {
	my $number = defined $args[1] ? $args[1] : 10;
	bg_do("top ".$number);
    } elsif ($args[0] eq 'cpan' && defined $args[1]) {
	call_openurl('http://search.cpan.org/search?mode=module&query='.$args[1]);
    } elsif ($args[0] eq 'autorun' && defined $args[1]) {
	toggle_autorun($args[1]);
    } elsif ($args[0] eq 'new') {
	my $number = defined $args[1] ? $args[1] : 5;
	bg_do("new ".$number);
    }
}

sub sig_command_script_load ($$$) {
    my ($script, $server, $witem) = @_;
    no strict;
    $script = $2 if $script =~ /(.*\/)?(.*?)\.pl$/;
    if (%{ "Irssi::Script::${script}::" }) {
	if (defined &{ "Irssi::Script::${script}::pre_unload" }) {
	    print CLIENTCRAP "%R>>%n Triggering pre_unload function of $script...";
	    &{ "Irssi::Script::${script}::pre_unload" }();
	}
    }
}

sub sig_default_command ($$) {
    my ($cmd, $server) = @_;
    return unless Irssi::settings_get_bool("scriptassist_check_unknown_commands");
    bg_do('unknown '.$cmd);
}

sub sig_complete ($$$$$) {
    my ($list, $window, $word, $linestart, $want_space) = @_;
    return unless $linestart =~ /^.script(assist)? (install|rate|ratings|update|check|contact|info|autorun)/;
    my @newlist;
    my $str = $word;
    foreach (@complist) {
	if ($_ =~ /^(\Q$str\E.*)?$/) {
	    push @newlist, $_;
	}
    }
    foreach (@{loaded_scripts()}) {
	push @newlist, $_ if /^(\Q$str\E.*)?$/;
    }
    $want_space = 0;
    push @$list, $_ foreach @newlist;
    Irssi::signal_stop();
}


Irssi::settings_add_str($IRSSI{name}, 'scriptassist_script_sources', 'http://www.irssi.org/scripts/scripts.dmp');
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_cache_sources', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_update_verbose', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_check_verbose', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_catch_script_errors', 1);

Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_install_unsigned_scripts', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_use_gpg', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_integrate', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_check_unknown_commands', 1);

Irssi::signal_add_first("default command", \&sig_default_command);
Irssi::signal_add_first('complete word', \&sig_complete);
Irssi::signal_add_first('command script load', \&sig_command_script_load);
Irssi::signal_add_first('command script unload', \&sig_command_script_load);

if (defined &Irssi::signal_register) {
    Irssi::signal_register({ 'script error' => [ 'Irssi::Script', 'string' ] });
    Irssi::signal_add_last('script error', \&sig_script_error);
}

Irssi::command_bind('scriptassist', \&cmd_scripassist);

Irssi::theme_register([
   'box_header' => '%R,--[%n$*%R]%n',
   'box_inside' => '%R|%n $*',
   'box_footer' => '%R`--<%n$*%R>->%n'
]);

foreach my $cmd ( ( 'check', 'install', 'update', 'contact', 'search', '-h', 'help', 'ratings', 'rate', 'info', 'echo', 'top', 'cpan', 'autorun', 'new') ) {
    Irssi::command_bind('scriptassist '.$cmd => sub {
			cmd_scripassist("$cmd ".$_[0], $_[1], $_[2]); });
    if (Irssi::settings_get_bool('scriptassist_integrate')) {
	Irssi::command_bind('script '.$cmd => sub {
    			    cmd_scripassist("$cmd ".$_[0], $_[1], $_[2]); });
    }
}

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /scriptassist help for help';
