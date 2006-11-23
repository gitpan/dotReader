#!/usr/bin/perl

use strict;
use warnings;

use Test::More (
  'no_plan'
  );

BEGIN { use_ok('dtRdr::Book::ThoutBook_1_0'); }
BEGIN { use_ok('dtRdr::Annotation::IO'); }
BEGIN { use_ok('dtRdr::Highlight') };

use File::Path qw(
  mkpath
  rmtree
);

local $SIG{__WARN__};

my $storage_dir = 't/annotation/temp';
rmtree($storage_dir);
(-d $storage_dir) and die "oops -- cannot cleanup $storage_dir";
mkpath($storage_dir);
(-d $storage_dir) or die "oops -- cannot create $storage_dir";

my $book_uri = 'test_packages/indexing_check/book.xml';
(-e $book_uri) or die "missing '$book_uri' ?!";

{ # big scope here

my $anno_io;
$anno_io = dtRdr::Annotation::IO->new(uri => $storage_dir);
ok($anno_io, 'constructor');
isa_ok($anno_io, 'dtRdr::Annotation::IO');
isa_ok($anno_io, 'dtRdr::Annotation::IO::YAML');

my $book = dtRdr::Book::ThoutBook_1_0->new();
ok($book, 'book');
isa_ok($book, 'dtRdr::Book');

$book->load_uri($book_uri);

ok(! $anno_io->items_for($book), 'nothing there');

$anno_io->apply_to($book);

my $toc = $book->toc;
{
  my $node = $toc->get_by_id('B');
  my $hl0 = dtRdr::Highlight->create(
    node => $node,
    range => [0, 1],
    id => 'foo'
    );
  $book->add_highlight($hl0);

  # check the finger-wagging
  eval { $book->add_highlight($hl0) };
  ok($@, 'denied');
  like($@, qr/duped.*foo/, 'useful message');
}
is(scalar($anno_io->items_for($book)), 1, 'count');

# and a few for good measure
$book->add_highlight( dtRdr::Highlight->create(
    node => $toc->get_by_id('B'), range => [0, 3], id => 'bar'
));
is(scalar($anno_io->items_for($book)), 2, 'count');
$book->add_highlight( dtRdr::Highlight->create(
    node => $toc->get_by_id('D'), range => [0, 3], id => 'baz'
));
is(scalar($anno_io->items_for($book)), 3, 'count');
$book->add_highlight( dtRdr::Highlight->create(
    node => $toc->get_by_id('A'), range => [0, 5], id => 'bat'
));
is(scalar($anno_io->items_for($book)), 4, 'count');

} # end big scope


########################################################################
{ # big scope here
# start again with on-disk checks
my $book = dtRdr::Book::ThoutBook_1_0->new();
ok($book, 'book');
isa_ok($book, 'dtRdr::Book');

$book->load_uri($book_uri);

my $anno_io = dtRdr::Annotation::IO->new(uri => $storage_dir);
ok($anno_io, 'constructor');
isa_ok($anno_io, 'dtRdr::Annotation::IO');
isa_ok($anno_io, 'dtRdr::Annotation::IO::YAML');
is(scalar($anno_io->items_for($book)), 4, 'got some files now');

eval { $anno_io->apply_to($book); };
ok(! $@, 'survived application');

{ # count them all again
  my $toc = $book->toc;
  is(scalar($book->local_highlights($toc->get_by_id('A'))), 1);
  is(scalar($book->local_highlights($toc->get_by_id('B'))), 2);
  is(scalar($book->local_highlights($toc->get_by_id('D'))), 1);
}

{ # mod one and run update
  my $toc = $book->toc;
  my ($hl) = $book->local_highlights($toc->get_by_id('A'));
  $hl->set_title("wibble");
  is($hl->title, 'wibble');
  $anno_io->update($hl);
}

{ # and delete another
  my $toc = $book->toc;
  my ($hl) = $book->local_highlights($toc->get_by_id('B'));
  $book->delete_highlight($hl);
}

} # end big scope

# once more to check update
{ # big scope here
# start again with on-disk checks
my $book = dtRdr::Book::ThoutBook_1_0->new();
ok($book, 'book');
isa_ok($book, 'dtRdr::Book');

$book->load_uri($book_uri);

my $anno_io = dtRdr::Annotation::IO->new(uri => $storage_dir);
ok($anno_io, 'constructor');
isa_ok($anno_io, 'dtRdr::Annotation::IO');
isa_ok($anno_io, 'dtRdr::Annotation::IO::YAML');
is(scalar($anno_io->items_for($book)), 3, 'got three files now');

eval { $anno_io->apply_to($book); };
ok(! $@, 'survived application');

{ # count them all again
  my $toc = $book->toc;
  is(scalar($book->local_highlights($toc->get_by_id('A'))), 1);
  { # check this guy
    my ($hl) = $book->local_highlights($toc->get_by_id('A'));
    is($hl->title, 'wibble', 'title mod');
  }
  is(scalar($book->local_highlights($toc->get_by_id('B'))), 1);
  is(scalar($book->local_highlights($toc->get_by_id('D'))), 1);
}
} # end big scope

# cleanup after ourselves
rmtree($storage_dir);

# vim:ts=2:sw=2:et:sta:syntax=perl
