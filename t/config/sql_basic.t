#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);

BEGIN {use_ok('dtRdr::Config::SQLConfig')};

use File::Basename qw(dirname);

my $dbfile = dirname($0) . '/' . 'testconfig.db';
(-e $dbfile) and unlink($dbfile);

{ # create, populate
  my $conf = dtRdr::Config::SQLConfig->new('sql:' . $dbfile);

  isa_ok($conf, 'dtRdr::Config');
  ok($conf->insert_library('foo1', 'bar2'));
  ok($conf->insert_library('bar1', 'bar2'));
  ok($conf->insert_library('baz1', 'bar2'));
}
{ # that should disconnect, see if it lived
  my $conf = dtRdr::Config::SQLConfig->new('sql:' . $dbfile);
  my @libraries = $conf->list_libraries;
  ok(3 == @libraries, 'count');
  foreach my $l (@libraries) {
    ok($l->[1] eq 'bar2') or warn join("|", @$l);
  }
}

# vim:ts=2:sw=2:et:sta
