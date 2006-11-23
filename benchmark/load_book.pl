#!/usr/bin/perl

# assumes you've got a toc in the book

use strict;
use warnings;

use lib 'lib';

use dtRdr::Book;
use dtRdr::Plugins;
dtRdr::Plugins->init;
use Time::HiRes ();

my $uri = $ARGV[0] or die "need a book name";

my $start = Time::HiRes::time();
my $book = dtRdr::Book->new_from_uri($uri);
my $diff = Time::HiRes::time() - $start;
warn "load in $diff seconds\n";

# vi:ts=2:sw=2:et:sta
