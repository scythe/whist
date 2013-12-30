
use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Irssi::Irc;
$VERSION = '0.99.6';
%IRSSI = (
    authors     => 'scythe',
    contact     => 'scythe on irc.mountai.net',
    name        => 'Whist 0.99.6',
    description => 'The perpetually-rewritten, never-finished metanet IRC whist bot. ',
    license     => 'Apache v2.',
);
#TODO: sort cards in hand
#give order of play
#fix first-round starter message
#add who-played-what annotation when printing the pile
#remove "get card xx from player" debug message
#announce winner of last trick properly
#pseudocode
#
#function whistplaycard(pile, player, cardnum, scoreround, getcard)
#   pile:add(player:pop(cardnum), player)
#   if(pile.len == 4) 
#      tailcall scoreround()
#   end
#   tailcall getcard()
#end
#
#function whistscoreround(round, trump, pile, players, startround, scoregame)
#   max = pile:card(0)
#   winner = 0
#   for i = 1, 3
#      max, winner = max > pile:card(i) ? max, winner : pile:card(i), i
#   end
#   players[winner].score++
#   if round == 13
#      tailcall scoregame()
#   end
#   tailcall startround()
#end
#
#function whistgetcard(round, players, turn, suit, player, card, playcard)
#   if round == 0 return end
#   if player != players[turn] end
#   [parse card]
#   if card not in player.cards return end
#   if suit and card.suit != suit return end
#   tailcall playcard(player, card)
#end
#
#function whistaddplayer(hands, players, player, getcard, channel, startround)
#   if player in players then return end
#   players:add(player, hands(len players))
#   whistsethandler(channel, player, function(message) tailcall getcard(player, message))
#   if len players = 4
#      tailcall startround()
#end
#
#function whistscoregame(players, scores, winscore, endgame, startround)
#   scores[0] += players[0].score + players[2].score
#   scores[1] += players[1].score + players[3].score
#   if scores[i] > winscore then 
#      [team i wins] tailcall endgame()
#   end
#   players[i].score = 0
#   tailcall startround()
#end
#
#function whist(dealer, channel, winscore)
#   pile = emptypile()
#   players = {dealer}
#   round = 0
#   turn = 0
#   scores = {0, 0}
#   playcard = function(player, cardnum) turn = turn + 1; tailcall whistplaycard(pile, player, cardnum, scoreround, getcard) end
#   getcard = function(player, card) tailcall whistgetcard(round, players, turn, pile.suit, player, card, playcard) end
#   addplayer = function(player) tailcall whistaddplayer(hands, players, player, getcard, channel, startround) end
#   startround = function() round = round == 13 ? 1 : round + 1; turn = 0 end
#   scoreround = function() tailcall whistscoreround(round, pile, players, startround, scoregame)
#   scoregame = function() tailcall whistscoregame(players, scores, winscore, endgame, startround)
#   endgame = function() tailcall whistendgame(players, channel)
#   [deal the cards]
#   return addplayer
#end

our %whistphandlers;
our %whistchandlers;

sub whist {
   my ($dealer, $channel, $server, $scoremax) = @_;
   my @players = ();
   my @pile = ();
   my @tscores = (0, 0);
   my %pscores = ();
   my %hands = ();
   my $turn = 0;
   my $round = 0;
   my $trump;
   my $say = sub {
      my ($message, $user) = @_;
      unless ($user) {
         $server->command("MSG $channel $message");
         return;
      }
      $server->command("MSG $user $message");
   };
   &$say("It works!");
   my $endgame = sub {
      my $winner = shift; 
      $winner++;
      &$say("team $winner wins!");
      @_ = (\@players, $channel);
      goto &whistendgame;
   };
   my $startround = sub { 
      $turn = shift;
      &$say("$players[$turn] won the round!");
      @pile = ();
      $round = $round + 1;
      for my $player (@players) {
         &$say(join(", ", $pscores{$player}, @{$hands{$player}}), $player);
      }
   };
   my $deal = sub {
      $round = 0;
      $trump = ('c', 'd', 'h', 's')[int(rand(4))];
      &$say("trump is $trump");
      &$say("team 1 score: $tscores[0] team 2 score $tscores[1]");
      @_ = (\@players, \%hands, $startround);
      goto &whistdeal;
   };
   my $scoregame = sub {
      @_ = (\@players, \%pscores, \@tscores, $scoremax, $endgame, $deal);
      goto &whistscoregame;
   };
   my $scoreround = sub {
      &$say(join(", ", @pile));
      @_ = ($round, $turn, \@pile, \@players, \%pscores, $trump, $startround, $scoregame);
      goto &whistscoreround;
   };
   my $playcard = sub {
      my ($player, $cardnum) = @_;
      &$say("get card $card from $player atop ");
      &$say(join(", ", @pile));
      $turn = ($turn + 1) % 4;
      @_ = (\@pile, $hands{$player}, $cardnum, $scoreround);
      goto &whistplaycard;
   };
   my $getcard = sub {
      my ($player, $card) = @_;
      @_ = ($round, \@players, $turn, \@pile, $player, $card, \%hands, $playcard);
      goto &whistgetcard;
   };
   my $addplayer = sub {
      my $player = shift;
      @_ = ($round, \@players, $player, $channel, $deal, $getcard);
      goto &whistaddplayer;
   };
   &$addplayer($dealer);
   return $addplayer;
}

sub whistendgame {
   my ($players, $channel) = @_;
   $whistphandlers{$channel} = undef;
   for my $player (@$players) {
      $whistchandlers{$player . $channel} = undef;
   }
}

sub whistscoregame {
   my ($players, $pscores, $tscores, $scoremax, $endgame, $deal) = @_;
   my $trickexcess = 0;
   my $sign = 1;
   for (my $i = 0; $i < 4; $i++) {
      $trickexcess = $trickexcess + $sign * $$pscores{$$players[$i]};
      $$pscores{$$players[$i]} = 0;
      $sign = $sign * -1;
   }
   if($trickexcess > 0) {
      $$tscores[0] = $$tscores[0] + $trickexcess;
      if($$tscores[0] >= $scoremax) {
         @_ = (0);
         goto &$endgame;
      }
   } else {
      $$tscores[1] = $$tscores[1] - $trickexcess;
      if($$tscores[1] >= $scoremax) {
         @_ = (1);
         goto &$endgame;
      }
   }
   goto &$deal;
}

sub whistgt {
   my ($cardl, $cardr, $trick, $trump) = @_;
   my %svals = ('c'=>0, 'd'=>0, 'h'=>0, 's'=>0, $trick => 20, $trump => 40);
   my %cvals = ('t' => 10, 'j' => 11, 'q' => 12, 'k' => 13, 'a' => 14);
   my ($cl, $sl) = ($cardl =~ /^(.)(.)/);
   my ($cr, $sr) = ($cardr =~ /^(.)(.)/);
   if($cvals{$cl}) {
      $cl = $cvals{$cl};
   }
   if($cvals{$cr}) {
      $cr = $cvals{$cr};
   }
   $sl = $svals{$sl};
   $sr = $svals{$sr};
   Irssi::print("comparing $cardl and $cardr subject to trick $trick and trump $trump gives $sl + $cl >? $sr + $cr");
   return ($sl + $cl) > ($sr + $cr);
}

sub whistscoreround {
   my($round, $prevwinner, $pile, $players, $scores, $trump, $startround, $scoregame) = @_;
   my $max = 0;
   my ($trick) = ($$pile[0] =~ /^.(.)/);
   for (my $i = 1; $i <= $#$pile; $i++) {
      if(whistgt($$pile[$i], $$pile[$max], $trick, $trump)) {
         $max = $i;
      }
   }
   $max = ($prevwinner + $max) % 4;
   $$scores{$$players[$max]}++;
   if($round == 13) {
      goto &$scoregame;
   }
   @_ = ($max);
   goto &$startround;
}

sub whistplaycard {
   my ($pile, $hand, $cardnum, $scoreround) = @_;
   push(@$pile, splice(@$hand, $cardnum, 1));
   if(scalar(@$pile) == 4) {
      goto &$scoreround;
   }
}

sub whistgetcard {
   my ($round, $players, $turn, $pile, $player, $card, $hands, $playcard) = @_;
   unless($$players[$turn] eq $player) {return;}
   my ($suit) = ($$pile[0] =~ /^.(.)/);
   my $cf = -1;
   my $sf = 0;
   my @hand = @{$$hands{$player}};
   for(my $i = 0; $i <= $#hand; $i++) {
      if ($hand[$i] eq $card) {
         $cf = $i;
      }
      if($hand[$i] =~ /^.$suit/) {
         $sf = 1;
      }
   }
   if($cf >= 0 and ($card =~ /^.$suit/ or $sf == 0)) {
      @_ = ($player, $cf);
      goto &$playcard;
   }
}

sub whistaddplayer {
   my ($round, $players, $player, $channel, $deal, $getcard) = @_;
   if($round != 0) { return; }
   for (my $i = 0; $i <= $#$players; $i++) {
      if($$players[$i] eq $player) { return; }
   }
   push(@{$players}, $player);
   $whistchandlers{$player . $channel} = sub {
       my $message = shift;
       @_ = ($player, $message);
       goto &$getcard;
   };
   if($#$players == 3) {
      goto &$deal;
   }
}

sub card {
   my $num = shift;
   my $suit = ('c', 'd', 'h', 's')[$num % 4];
   my $num = (2,3,4,5,6,7,8,9,'t','j', 'q', 'k', 'a')[int($num/4)];
   return $num . $suit;
}

sub whistdeal {
   my ($players, $hands, $startround) = @_;
   my @list;
   my $count = 0;
   my $place;
   for my $i (0..200) {
      $list[$i] = -1;
   }
   while($count < 52) {
      $place = int(rand(200));
      if($list[$place] == -1) {
         $list[$place] = $count;
         $count = $count + 1;
      }
   }
   $count = 0;
   for my $i (0..200) {
      if($list[$i] != -1) {
         push(@{$$hands{$$players[$count%4]}}, card($list[$i]));
         $count = $count + 1;
      }
   }
   @_ = (int(rand(4)));
   goto &$startround;
}

sub event_privmsg {
   my ($server, $data, $nick, $address) = @_;
   my ($target, $text) = split(/ :/, $data, 2);
   if($target =~ /^#/ && $text =~ /^!deal ([0-9]*)/) {
      Irssi::print("deal received $1");
      $whistphandlers{$target} = whist($nick, $target, $server, $1);
   }
   if($whistphandlers{$target} && $text =~ /^!join/) {
      &{$whistphandlers{$target}}($nick);
   }
   if($whistchandlers{$nick . $target} && $text =~ /\[([2-9tjqka][cdhs])\]/) {
      &{$whistchandlers{$nick . $target}}($1);
   }
   if($text =~ /^!whist-help/) {
      $server->command("MSG $target whistbot 0.99.6 deals a game of whist via IRC. See http://en.wikipedia.org/wiki/Whist for gameplay.");
      $server->command("MSG $target A game is started by typing !deal [number], where [number] is the score the game is played to, often 7. Players join by saying !join");
      $server->command("MSG $target Your hand is PMed to you and cards are in the form [number][suit] where number is of the form [2-9tjqka] and suit is [cdhk].");
      $server->command("MSG $target A card is thrown by typing [card], *with* the brackets, e.g. [9c], [ts], [4d], [kh]. Your partner is automatically chosen by the order of !joins.");
      $server->command("MSG $target Currently the dealer and second !joiner are on team 1, and the other two players are on team 2.");
   }
}

Irssi::signal_add("event privmsg", "event_privmsg");

