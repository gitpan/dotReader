use Test::More 'no_plan';

use lib 'inc';
use dtRdrTestUtil qw(
  error_catch
  );

use strict;
use warnings;

BEGIN {use_ok('dtRdr::Library::SQLLibrary')};

local $TODO = "Catch the DBI errors --Eric";
warn "\nTODO: finish this\n ";

my $NOPATH = '/tmp/this/should/not/exist/';
(-e $NOPATH) and die "whiskey tango foxtrot?";
my ($noise, $err) = error_catch(sub {
    eval {
      dtRdr::Library::SQLLibrary->create($NOPATH);
    };
    return($@ || '');
  });

ok((not $noise), 'no noise') or complain($noise);
ok((not $@), 'no err') or complain($@);

sub complain {
  0 and warn @_, "-- at " , join(" line ", (caller(0))[1,2]);
} # end subroutine complain definition
########################################################################
# vim:ts=2:sw=2:et:sta
