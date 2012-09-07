use Irssi 20020101.0250 ();
$VERSION = "3";
%IRSSI = (
    authors     => 'David Leadbeater',
    contact     => 'dgl@dgl.cx',
    name        => 'getnick',
    description => 'gets or keeps a specific nickname',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.dgl.yi.org/',
);

# /GETNICK <nick> <tag> - gets the specified nick for you
# /KEEPNICK <tag> - keeps the current nick
# /UNGETNICK all | <tag>
# /UNKEEPNICK all | <tag>

use strict;
my(%keepnick,%getnick);

sub checknick{
   for(keys %keepnick){
      my $server = Irssi::server_find_tag($_);
	  next if !$server;
	  if($server->{nick} ne $keepnick{$_}){
	     $getnick{$_} = $keepnick{$_};
	  }
   }

   for(keys %getnick){
     my $server = Irssi::server_find_tag($_);
	 next if !$server; # if no connection skip unitl we have one
	 my $getnick = $getnick{$_};
	 if($server->{nick} eq $getnick){
	    # the nick was changed manually
	    delete($getnick{$_});
	    next;
	 }
	 $server->send_raw("ISON :$getnick");
	 Irssi::signal_add_first("event 303", "isonredir");
   }
}

sub isonredir{
   my($server,$text) = @_;
   Irssi::signal_remove("event 303", "isonredir");
   my $nick = $getnick{$server->{tag}};
   return if !$nick;
   if($text !~ /:\Q$nick\E\s?$/i){
      $server->send_raw("NICK :$nick");
   }
   Irssi::signal_stop();
}

sub getnick{
   my($getnick,$tag) = split(/ /,shift,2);
   $tag = Irssi::active_server->{tag} if !$tag && $getnick;
   my $server = Irssi::server_find_tag($tag);
   if($server){
      if ($server->{nick} ne $getnick) {
         Irssi::print("Now trying to get $getnick on $tag");
         $getnick{$tag} = $getnick;
	    checknick();
      } else {
         Irssi::print("Your nick is already $getnick");
      }
   }elsif($getnick && $tag) {
	  Irssi::print("Invaild chat network specified see /ircnet list");
   }else{
      Irssi::print("Usage: /getnick nickname tag");
	  for(keys %getnick) {
		 Irssi::print("Trying to get $getnick{$_} on $_");
	  }
   }
}

sub ungetnick{
   my $tag = shift;
   $tag = Irssi::active_server->{tag} if !$tag;
   if($tag eq lc("all")){
     Irssi::print("Stopped trying to get all nicks");
     %getnick = {};
   }elsif($getnick{$tag}){
      Irssi::print("Stopped trying to get $getnick{$tag} on $tag");
	  delete($getnick{$tag});
   }else{
      Irssi::print("Usage: /ungetnick tag/all");
   }
}

sub keepnick{
   my($tag) = shift;
   $tag = Irssi::active_server->{tag} if !$tag;
   my $server = Irssi::server_find_tag($tag);
   if(defined $server){
      Irssi::print("Now keeping ".$server->{nick}." on $tag");
      $keepnick{$tag} = $server->{nick};
   }elsif($tag) {
	  Irssi::print("Invaild chat network specified see /ircnet list");
   }else{
      Irssi::print("Usage: /keepnick tag");
	  for(keys %keepnick) {
		 Irssi::print("Keeping $keepnick{$_} on $_");
	  }
   }
}

sub unkeepnick{
   my $tag = shift;
   $tag = Irssi::active_server->{tag} if !$tag;
   if($tag eq lc("all")){
     Irssi::print("Stopped trying to keep all nicks");
     %keepnick = {};
   }elsif($keepnick{$tag}){
      Irssi::print("Stopped trying to keep $keepnick{$tag} on $tag");
	  delete($keepnick{$tag});
   }else{
      Irssi::print("Usage: /unkeepnick tag/all");
   }
}

sub quit{
   my($server,$oldnick) = @_;
   if($oldnick eq $getnick{$server->{tag}}){
      $server->send_raw("NICK :$oldnick");
   }
}

sub nick{
   my($server,$newnick,$oldnick) = @_;
   if($oldnick eq $getnick{$server->{tag}}){
      $server->send_raw("NICK :$oldnick");
   }
}

sub own_nick{
   my($server,$newnick,$oldnick) = @_;
   if(defined $getnick{$server->{tag}} && 
      $newnick eq $getnick{$server->{tag}}){
	  delete($getnick{$server->{tag}});
   }elsif($keepnick{$server->{tag}}) {
	  Irssi::print("Nickname changed, stopped trying to keep $keepnick{$server->{tag}}");
	  delete($keepnick{$server->{tag}});
   }
}

Irssi::timeout_add(12000, 'checknick','foo');

Irssi::signal_add('message quit', 'quit');
Irssi::signal_add('message nick', 'nick');
Irssi::signal_add('message own_nick', 'own_nick');

Irssi::command_bind("getnick", 'getnick');
Irssi::command_bind("keepnick", 'keepnick');
Irssi::command_bind("ungetnick", 'ungetnick');
Irssi::command_bind("unkeepnick", 'unkeepnick');

