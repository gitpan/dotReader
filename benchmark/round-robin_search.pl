#!/usr/bin/perl

# how long does it take to get one answer for each node in the search hits?

use strict;
use warnings;

use lib 'lib';

use dtRdr::Book::ThoutBook_1_0;
use dtRdr::Search::Book;

use Time::HiRes ();


my $uri = $ARGV[0] or die "need book name";
my $regexp = $ARGV[1] or die 'need to search for something';
$regexp = qr/$regexp/;

my $book = dtRdr::Book::ThoutBook_1_0->new();
$book->load_uri($uri);

my $sizer = sub {
  my ($name, $var) = @_;
  eval {require Devel::Size} or return;
  my $size = sprintf("%0.4f", Devel::Size::total_size($var) / 1024**2);
  print "$name is $size MB\n";
};

$sizer->('book', $book); # 44MB
my $content = $book->get_xml_content;
$sizer->('raw content', $content);
my $search = dtRdr::Search::Book->new(book => $book, find => $regexp);

{ # burn through the quicksearch
  my $start = Time::HiRes::time();
  while($search->quick_searcher) {
    my $result = $search->quick_next
  }
  my $diff = Time::HiRes::time() - $start;
  # 0.7 for 'open' in perlbook
  warn "quicksearch took $diff seconds";
}

if(1) {
  my $start = Time::HiRes::time();
  my %hold;
  foreach my $node (@{$search->{_search_nodes}}) {
    $hold{$node} = $book->get_NC($node);
  }
  my $diff = Time::HiRes::time() - $start;
  $sizer->('cache', \%hold);
  $sizer->('book now', $book);
  warn "get_NC's took $diff seconds";
}
else { # then go grab the plan
  my $start = Time::HiRes::time();
  my %hold;
  foreach my $node (@{$search->{_search_nodes}}) {
    $hold{$node} = $book->get_trimmed_content($node);
  }
  my $diff = Time::HiRes::time() - $start;
  $sizer->('cache', \%hold);
  # 32.7 for 'open' in perlbook
  warn "gets took $diff seconds";
}

# Suppose we could weight the quicksearch by the number of hits a given
# node had and do those first?


# vi:ts=2:sw=2:et:sta
