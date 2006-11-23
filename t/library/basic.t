use Test::More (
  skip_all => 'this library needs love'
);

use strict;
use warnings;

BEGIN {use_ok('dtRdr::Library::SQLLibrary')};

# Note that our default SQLLibrary handler is the SQLite module
#dtRdr::Plugins::set_handler(dtRdr::Plugins::LIBRARY, 'SQLLibrary', "sample SQLite library");

my $LIBLOC = 't/library/';

# Toss the test library if it exists
if (-e $LIBLOC . 'testlib.db') {
   unlink $LIBLOC . 'testlib.db';
}

my $BOOK1 = 'FreeBSD Developers\' Handbook';
my $BOOK2 = 'Perl 5.8 Documentation';
# we can have two copies of an id if they're a different title
my $BOOK3 = 'FreeBSD Developers\' Handbook';

# first run
{
  dtRdr::Library::SQLLibrary->create($LIBLOC . 'testlib.db');
  my $library = dtRdr::Library::SQLLibrary->new();
  $library->load_uri($LIBLOC . 'testlib.db');
  ok($library, 'constructor');

  isa_ok($library, 'dtRdr::Library');


  $library->add_book(
    id    => $BOOK1,
    title => $BOOK1,
    uri   => '../../test_packages/FreeBSD_Developers_Handbook.jar',
    type  => 'Thout_1_0_jar'
  );
  $library->add_book(
    id    => $BOOK2,
    title => $BOOK2,
    uri   => '../../test_packages/osoft_9Perl5.8manual_en.jar',
    type  => 'Thout_1_0_jar'
  );
  $library->add_book(
    id    => $BOOK3,
    title => $BOOK3 . ' (unzipped)',
    uri   => '../../test_packages/FreeBSD_Developers_Handbook/FreeBSDDevelopersHandbook.xml',
    type  => 'Thout_1_0'
  );
  ok(1, 'Added books');

  my @books = $library->get_book_info();
  ok(@books == 3, "Book info hashes");
  can_ok($_, 'title') for(@books);
  ok($books[0]->title eq $BOOK1, "checked book info hash");
  ok($books[1]->title eq $BOOK2, "checked book info hash");
  ok($books[2]->id    eq $BOOK3, "checked book info hash");
  ok($books[2]->title eq $BOOK3 . ' (unzipped)', "checked book info hash");

  $library->set_info('name', 'test library');
  my $name = $library->get_info('name');
  ok($name eq 'test library', "library info");

  undef($library);
}

# second run
{
my $library = dtRdr::Library::SQLLibrary->new();
$library->load_uri($LIBLOC . 'testlib.db');
isa_ok($library, 'dtRdr::Library');

my @books = $library->get_book_info();
ok(@books == 3, 'book set');

my $book = $library->open_book(title => $BOOK1);
isa_ok($book, 'dtRdr::Book');
isa_ok($book, 'dtRdr::Book::ThoutBook_1_0_jar');

my (@toc) = $book->toc->children;
my $toc = $toc[0];
isa_ok($toc, 'dtRdr::TOC');
}
{
my $library = dtRdr::Library::SQLLibrary->new();
$library->load_uri($LIBLOC . 'testlib.db');
isa_ok($library, 'dtRdr::Library');

my @books = $library->get_book_info();
ok(@books == 3, 'book set');

my $book = $library->open_book(title => $BOOK3 . ' (unzipped)');
isa_ok($book, 'dtRdr::Book');
isa_ok($book, 'dtRdr::Book::ThoutBook_1_0');

my (@toc) = $book->toc->children;
my $toc = $toc[0];
isa_ok($toc, 'dtRdr::TOC');
}

# vim:ts=2:sw=2:et:sta
