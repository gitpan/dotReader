#!/usr/bin/perl

# vim:ts=2:sw=2:et:sta:syntax=perl

use strict;
use warnings;

use Test::More (
  'no_plan'
  );

BEGIN { use_ok('dtRdr::Book::ThoutBook_1_0') };
BEGIN {use_ok('dtRdr::Bookmark');}
BEGIN {use_ok('dtRdr::Note');}

use lib 'inc';
use dtRdrTestUtil::Expect;

my $book = open_book(
  'dtRdr::Book::ThoutBook_1_0',
  'test_packages/indexing_check/book.xml'
);

check_toc(['A'..'G']);
# we still need to do these to pre-populate the cache
expect_test('A', '0123456789');
expect_test('B', '123');
expect_test('C', '2');
expect_test('D', '456');
expect_test('E', '5');
expect_test('F', '8');
expect_test('G', '9');

{
  my $range = find_test('A  0 - 1 A 0 1');
  my $bm = mk_bookmark($range);
  bookmark_test('A', '0');
  $book->delete_bookmark($bm);
}

{ # a bookmark with undef range should apply to everything in the node
  my $node = $book->find_toc('A');
  my $bm = dtRdr::Bookmark->create(node => $node, range => [undef,undef]);
  isa_ok($bm, 'dtRdr::Bookmark');
  $book->add_bookmark($bm);
  bookmark_test('A', '0123456789');

  # XXX unfortunately, this is also true (and is why we shouldn't have
  # two views of the same content within a subtree)
  bookmark_test('B', '123');
  $book->delete_bookmark($bm);
}

{ # and sneak in a note test here too
  my $node = $book->find_toc('A');
  my $nt = dtRdr::Note->create(node => $node, range => [undef,undef]);
  isa_ok($nt, 'dtRdr::Note');
  $book->add_note($nt);
  note_test('A', '0123456789');

  note_test('B', '123');
  $book->delete_note($nt);
}
