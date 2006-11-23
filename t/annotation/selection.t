#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);
use lib 'inc';
use dtRdrTestUtil::ABook;

BEGIN {use_ok('dtRdr::Selection');}

my $book = ABook_new_1_0('test_packages/QuickStartGuide/quickstartguide.xml');
my $node = $book->find_toc($book->toc->id);
$book->get_content($node);
my $sel = $book->locate_string(
  $node,
  'ThoutReaderTM v 1.7 Copyright 2005, OSoft, Inc',
  'Quick Start Guide for ',
  '.'
  );
isa_ok($sel, 'dtRdr::Selection', 'isa selection');
is(
  $sel->get_selected_string,
  'ThoutReaderTM v 1.7 ...ght 2005, OSoft, Inc',
  'string result'
);



# vim:ts=2:sw=2:et:sta:syntax=perl
