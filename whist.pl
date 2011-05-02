use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Irssi::Irc;
$VERSION = '0.99.3';
%IRSSI = (
    authors     => 'scythe',
    contact     => 'scythe on irc.mountai.net',
    name        => 'Whist 0.99.3',
    description => 'This script allows ' .
    'you to print Hello ' .
    'World using a command.',
    license     => 'Public Domain',
);


# global variables
our @hands;	# Contains cards in the order of shuffling, so that player 1's hand is cards 0-12, player 2 has cards 13-25, et cetera. 
our @deck;	# Acts as a reverse-index to the hands array.
our $playing;	# 0 -- not playing, 1 -- playing, 2 -- adding players
our $trick;	# number of the trick we're on. Counts from 1, I know, sue me.
our @players;
our $numplayers;
our $turn;
our @trickcards;
our @player_scores;

sub array_concat {
	my $ret = "";
	foreach my $c (@_) {
		$ret = $ret . " " . $c;
	}
	return $ret;	
}

sub new_deck {		# defines a bunch of global variables. Sue me, SPJ.

	$playing = 2;
	$trick = 0;		
	@deck = ();		
	@hands = ();	
	
	my $i = 0;
	for(; $i < 52; $i++) {
		my $card = int(rand() * (52 - $i));
		my @hands_sorted = sort {$a<=>$b} (@hands);
		Irssi::print("$card");
		Irssi::print(array_concat(@hands_sorted));
		foreach my $c (@hands_sorted) {
			if($card >= $c) {
				$card = $card + 1
			}
		}
		Irssi::print("$card");
		$hands[$i] = $card;
		$deck[$hands[$i]] = $i;
	}
	Irssi::print(array_concat(@hands));
	Irssi::print(array_concat(@deck));
}

sub play_card {
	my ($cardnum, $player, $server, $target) = @_;
	package main;
	
	my $position = $deck[$cardnum];
	if($position == -1) {
		return;
	}
	my $owner = int($position / 13);
	my $owner_name = $players[$owner];
	if($player ne $owner_name) { 	# if the person trying to play the card is not the person who has it in their hand
		$server->command("MSG $target That's not your card!");
		return;
	}
	$trickcards[$turn] = $hands[$position];
	$hands[$position] = -1;
	$deck[$cardnum] = -1;
	$turn++;
	if($turn == 4) {
		return score_trick($server, $target);
	}
}

sub score_trick {
	my ($server, $target) = @_;
	my $tc_max = -1;
	my $tc_winner = -1;
	for(my $i = 0; $i < 4; $i++) {
		if($trickcards[$i] > $tc_max) {
			$tc_winner = $i;
			$tc_max = $trickcards[$i];
		}
	}
	$server->command("MSG $target " . $players[$tc_winner] . " wins the trick with " . untranslate($tc_max));
	$player_scores[$tc_winner] += 1;
	$server->command("MSG $target " . array_concat(@players));
	$server->command("MSG $target " . array_concat(@player_scores));
	$turn = 0;
	
	if($trick == 13) {
		return end_game($server, $target);
	}
}

sub end_game {
	my ($server, $target) = @_;
	my $ps_winner = -1;
	my $ps_max = -1;
	for(my $i = 0; $i < 4; $i++) {
		if($player_scores[$i] > $ps_max) {
			$ps_winner = $i;
			$ps_max = $player_scores[$i];
		}
	}
	$server->command("MSG $target " . $players[$ps_winner] . " wins with " . $player_scores[$ps_winner] . " points!");
	$playing = 0;
	$trick = 0;
	$numplayers = 0;
	$turn = 0;
	@player_scores = qw(0 0 0 0);
}

sub handle_msgs {
	my ($server, $data, $nick, $address) = @_;
	my ($target, $message) = split(/:/, $data);

	my $serv = Irssi::active_server();

	if(substr($message,0,5) eq "!deal" and ($playing == 0 or $server->command("MSG $target We're already playing!") and 0)) {
		new_deck();
	}
	if(substr($message,0,5) eq "!play" and ($playing == 1 or $server->command("MSG $target We haven't started yet!") and 0)) {
		play_card(translate(substr($message, 6)), substr($nick,0,length($nick) - 1), $server, $target);
	}
	if(substr($message, 0, 5) eq "!join" and ($playing == 2 or $server->command("MSG $target You have to wait for the next game.") and 0)) {
		$players[$numplayers] = $nick;
		$numplayers++;
		my $hand = "";
		for(my $i = ($numplayers - 1) * 13; $i < $numplayers * 13; $i++ ) {
			$hand = $hand . untranslate($hands[$i]);
		}
		$server->command("MSG $nick Your hand contains $hand ");
		if($numplayers = 4) {
			$trick = 1;
			$turn = 0;
			@player_scores = qw(0 0 0 0);
			$server->command("MSG " . $players[0] . " it's your turn.");
		}
	}
	#Irssi::print("server: $server data: $data nick: $nick address: $address");
}

sub translate {					# converts number / suit format to card numbers
	my ($arg) = @_;
	my ($num, $suit) = split(/\s+/, $arg);  # cards must have number and suit separated by a space
	my %suits = qw (c 0 d 1 h 2 s 3);
	my %nums = qw(a 14 k 13 q 12 j 11);
	if(not $suits{$suit}) {
		return -1;
	}
	if($nums{$num}) {$num = $nums{$num};}
	return ($num - 2) * 4 + $suits{$suit};
}
sub untranslate {				# converts card numbers to number / suit format
	my ($cardnum) = @_;
	my $num = ($cardnum - $cardnum % 4) / 4 + 2;	# this is an awful way to do this but fuck it
	my $suit = $cardnum % 4;
	my %suits = qw (0 c 1 d 2 h 3 s);
	my %nums = qw(14 a 13 k 12 q 11 j);
	$suit = $suits{$suit};
        if($nums{$num}) {$num = $nums{$num};}
	return "$num $suit";
}
# 1;
our $playing = 0;
Irssi::signal_add('event privmsg', 'handle_msgs');

my $serv = Irssi::active_server();
if(defined($serv) && $serv && $serv->{connected}) {
	Irssi::print("$serv");
}
