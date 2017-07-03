#!/usr/bin/perl

# When solving a problem for the first time, I usually proceed like this:

# I produce a first iteration that is very minimalist and focuses on 
# solving the problem. Having a limited quantity of code helps me to quickly
# spot flows in my implementation and also allows me to easily debug it.

# I will then add more test data and see if new bugs are showing.
# For example, I added a new Return in client1.csv:
# C1,R,ABC98765:2,HK345675432,3000,ABC98765
# And I could notice that my code is not working properly with a more complex
# dataset where there is more than one Return per Trade.

# The code below is this very minimal version, where I used the power of Perl
# data structures instead of a full fledged OO lib.

# Later, when integrating my code to an existing codebase, I adapt the code 
# to follow the guidelines and paradigms in use. I can for example define
# classes for Trades and Returns.

# To solve this problem quickly, my strategy was to use a CSV parser and
# reorganize each transation data using nested hashrefs to be able to access
# the data this way: $$client{T}{HK345675432}{Quantity}.
# I then use for loops to compare trades and returns separately. I compare file
# A to file B, and then file B to file A, to be sure to spot missing Trades or
# Returns. My short solution consists in 4 functions.

# To handle more fields in the future, I would add a new check function per
# field. If the code becomes too repetitive, I try to write a more generic check
# function to factorize. In a more object oriented approach, I can add one check
# method per field and use polymorphism to avoid repetitive code.

# The problems in my implementation:
# - The field names of the CSV are directly mapped to my data structure. This is
#   wrong because it prevents me to handle more than one file format.
#   It needs to be more abstract. Seeing more file formats would serve as a base
#   for a more abstract implementation.
# - checkMissingTrades and checkMissingReturns may be factorized by passing a T
#   or an R as argument. I didn't do it because the log messages are different.

# I would also give a try to this CPAN module:
# http://search.cpan.org/~chateau/Data-Reconciliation-0.07/lib/Data/Reconciliation.pm

use Modern::Perl;
use Text::CSV::Simple;
#use Data::Dumper;

my $parser = Text::CSV::Simple->new;
$parser->field_map(qw/Client TradeOrReturn Reference Security Quantity Parent/);

my @client1 = $parser->read_file("client1.csv");
my @client2 = $parser->read_file("client2.csv");

# Builds a nested data structure based on hashrefs where records are indexed by
# TradeOrReturn and Security
sub organize {
  my $client = shift;
  my $c = {};
  $$c{$$_{TradeOrReturn}}{$$_{Security}} = $_ for @$client;
  # Store the client reference at the root of the hashref for quick access
  $$c{Client} = @{$client}[0]->{Client};
  return $c;
}

# Check for missing trades
sub checkMissingTrades {
  my ($ca, $cb) = @_;
  for my $sec (keys %{$$ca{T}}) {
    say "Client $$cb{Client} is missing a trade ",
    "of $$ca{T}{$sec}{Quantity} ",
    "for security $sec"
    if ! exists $$cb{T}{$sec};
  }
}

# Check for missing returns
sub checkMissingReturns {
  my ($ca, $cb) = @_;
  for my $sec (keys %{$$ca{R}}) {
    say "Client $$cb{Client} is missing a return ",
    "for $$ca{R}{$sec}{Quantity} ",
    "on position $$cb{T}{$sec}{Reference}"
    if ! exists $$cb{R}{$sec};
  }
}

# Check for wrong returns quantities
sub checkWrongReturnsQuantities {
  my ($ca, $cb) = @_;
  for my $sec (keys %{$$ca{R}}) {
    say "Client $$cb{Client} has a quantity ",
    "of $$cb{R}{$sec}{Quantity} on return $$cb{R}{$sec}{Reference} ",
    "that should be $$ca{R}{$sec}{Quantity}"
    if exists $$cb{R}{$sec}
    and $$cb{R}{$sec}{Quantity} < $$ca{R}{$sec}{Quantity};
  }
}

# Organize both clients records
my $c1 = organize \@client1;
my $c2 = organize \@client2;

checkMissingTrades($c1, $c2);
checkMissingTrades($c2, $c1);

checkMissingReturns($c1, $c2);
checkMissingReturns($c2, $c1);

checkWrongReturnsQuantities($c1, $c2);
checkWrongReturnsQuantities($c2, $c1);
