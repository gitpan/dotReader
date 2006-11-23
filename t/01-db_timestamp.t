#!/usr/bin/perl

# check the timestamps of the .db and dump files

# we may find reason to disable this at some point
# maybe better to just do this via a build dependency

use strict;
use warnings;

use Test::More (
  skip_all => 'Not using SQLite right now'
);

my @files = qw(
  SQL_Library.db
  drconfig.db
  );

my @dumps = map({"client/setup/$_.sql"} @files);

for(my $i = 0; $i < @files; $i++) {
  ok(-e $files[$i], 'exists') or BAIL_OUT(" \n  '$files[$i]' is missing");
  my ($t, $s) = map({(stat($_))[9]} $files[$i], $dumps[$i]);
  ok(($t > $s), 'target older than source') or
    BAIL_OUT("target $files[$i] older than source");
}

# vim:ts=2:sw=2:et:sta:syntax=perl
