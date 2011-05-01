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
our $playing;
our $trick;	# number of the trick we're on. Counts from 1, I know, sue me.
our @players;

sub array_concat {
	my $ret = "";
	foreach my $c (@_) {
		$ret = $ret . " " . $c;
	}
	return $ret;	
}

sub new_deck {		# defines a bunch of global variables. Sue me, SPJ.

	$playing = 1;
	$trick = 1;		
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
	$hands[$position] = -1;
	$deck[$cardnum] = -1;
	return;
}

sub handle_msgs {
	my ($server, $data, $nick, $address) = @_;
	my ($target, $message) = split(/:/, $data);

	my $serv = Irssi::active_server();

	if(substr($message,0,5) eq "!deal" and length($message) > 6) {
		
		if($playing == 0) {
			
			@players = split(/\s+/, substr($message,6));
			Irssi::print(array_concat(@players));
			
			my $last = $players[3] or Irssi::print("Not enough players!");
			if($last) {
				new_deck();
			}
		} else {
			$server->command("MSG $target We're already playing!");
		}
	}
	Irssi::print(substr($message, 0, 5));
	if(substr($message,0,5) eq "!play") {
		if($playing == 1) {
			play_card(translate(substr($message, 6)), substr($nick,0,length($nick) - 1), $server, $target);
		} else {
			$server->command("MSG $target We haven't started yet!");
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
