#!/usr/bin/perl

use warnings;
use strict;

local $SIG{__WARN__};

use lib 'lib';
use dtRdr::Book::ThoutBook_1_0;
use dtRdr::Search::Book;

my $book_uri = 'test_packages/search_test.edge_cases/book.xml';
my $book = dtRdr::Book::ThoutBook_1_0->new();
$book->load_uri($book_uri);

# this is way too odd.  If I don't have the dots in the regexps, I have
# to print something on stderr?

if(1) {
  my $searcher = dtRdr::Search::Book->new(
    book => $book,
    find => qr/I./
  );
  my @results;
  while(my $hit = $searcher->next) {
    $hit->null and next;
    push(@results, $hit);
  }
  scalar(@results) == 1 and print "ok 1\n";
  #foreach my $result (@results) {
  #  isa_ok($result, 'dtRdr::Search::Result', 'derived from result');
  #  isa_ok($result, 'dtRdr::Search::Result::Book', 'a book result');
  #}
  #is($results[0]->start_node->id, 'G');
}
if(1) {
  my $searcher = dtRdr::Search::Book->new(
    book => $book,
    find => qr/K./
  );
  my @results;
  while(my $hit = $searcher->next) {
    $hit->null and next;
    push(@results, $hit);
  }
  scalar(@results) == 1 and print "ok 2\n";
  #foreach my $result (@results) {
  #  isa_ok($result, 'dtRdr::Search::Result', 'derived from result');
  #  isa_ok($result, 'dtRdr::Search::Result::Book', 'a book result');
  #}
  #is($results[0]->start_node->id, 'G');
}

