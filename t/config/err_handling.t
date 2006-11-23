#!/usr/bin/perl

use strict;
use warnings;

use Test::More (
  'no_plan'
  );

use lib 'inc';
use dtRdrTestUtil qw(
  error_catch
  );

BEGIN {use_ok('dtRdr::Config::SQLConfig')};

use File::Basename qw(dirname);

{ # create without type:
  my $dbfile = dirname($0) . '/' . 'testconfig.db';
  my ($noise, $err) = error_catch(sub {
    eval {
      my $conf = dtRdr::Config::SQLConfig->new($dbfile);
    };
    return($@ || '');
  });

  like($err, qr/type undef/, 'type undef');
}

# vim:ts=2:sw=2:et:sta
