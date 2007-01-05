#!/usr/bin/perl

use warnings;
use strict;

use Benchmark qw(:all);

use lib 'lib';

use dtRdr::Book;
use dtRdr::Plugins;
dtRdr::Plugins->init;

use Time::HiRes ();

# TODO setup a known annoio source, logger

# get parameters
my $uri = $ARGV[0];
$uri = 'test_packages/big_section/book.xml' unless(defined($uri));
my $section = $ARGV[1];
# default to section 1 -- that's the big section in big_section
$section = 1 unless(defined($section));

my $start = Time::HiRes::time();
my $book = dtRdr::Book->new_from_uri($uri);
my $diff = Time::HiRes::time() - $start;
warn "load in $diff seconds\n";

my $node;
if($section =~ s/ID://) {
  $node = $book->find_toc($section);
}
else {
  $node = ($book->toc->children)[$section];
}

$node or die;
my $subref = sub {
  $book->get_content($node)
};

# TODO this isn't quite correct anymore, since changes have affected
# more than just the one method.  Needs to do IPC::Run on something like
# perl -Ibenchmark/lib74 -e '
#   use Benchmark;
#   ...
#   print YAML::Dump(time_this(...))'
# then reconstitute those results in this process and compare.

# we have to break it into two pieces
my $count = 0;
my %results;
$results{current} = timethis($count, $subref, 'current'); 

# grab the old definition
my $insert = do("./benchmark/book.pm-insert_nbh-r74.pm") or die;
{
  no warnings 'redefine';
  *dtRdr::Book::insert_nbh = $insert;
}

$results{r74} = timethis($count, $subref, 'r74');

cmpthese(\%results);

# vi:ts=2:sw=2:et:sta
