#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);

BEGIN {use_ok('dtRdr::Config::YAMLConfig')};

use File::Basename qw(dirname);

my $dbfile = dirname($0) . '/' . 'testconfig.yml';
(-e $dbfile) and unlink($dbfile);

{ # create, populate
  my $conf = dtRdr::Config::YAMLConfig->new('yaml:' . $dbfile);

  isa_ok($conf, 'dtRdr::Config');
  is($conf->add_library(uri => 'foo1', type => 'bar2'), 0);
  is($conf->add_library(uri => 'bar1', type => 'bar2'), 1);
  is($conf->add_library(uri => 'baz1', type => 'bar2'), 2);
}
{ # that should disconnect, see if it lived
  my $conf = dtRdr::Config::YAMLConfig->new('yaml:' . $dbfile);
  my @libraries = $conf->get_library_info;
  ok(3 == @libraries, 'count');
  foreach my $l (@libraries) {
    is($l->type, 'bar2') or warn join("|", %$l);
  }
}

# vim:ts=2:sw=2:et:sta
