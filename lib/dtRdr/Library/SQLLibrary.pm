package dtRdr::Library::SQLLibrary;
$VERSION = eval{require version}?version::qv($_):$_ for(0.1.1);


use warnings;
use strict;
use Carp;

use base 'dtRdr::Library';
use dtRdr::Library (
  register => {
    type => 'SQLLibrary'
  },
);
sub type {'SQLLibrary';} # needs to go away when plugins work

use dtRdr::Metadata;

use Class::Accessor::Classy;
no  Class::Accessor::Classy;

use DBI;
use File::Basename qw(
  dirname
);

# BEGIN {
#   dtRdr::Plugins::add_potential_handler(LIBRARY, 'SQLLibrary', "sample SQLite library", \&lib_open);
# }

=head1 NAME

dtRdr::Library::SQLLibrary - an SQLite library handler

=cut


=head2 load_uri

  $lib->load_uri($filename);

=cut

sub load_uri {
  my $self = shift;
  my ($file) = @_;

  (-e $file) or croak("cannot find library file '$file'");

  my $dbh = DBI->connect(
    "dbi:SQLite:$file", '', '',
    {RaiseError => 1}
  ) or croak("cannot open library database '$file'");
  $self->{location} = $file;
  $self->{database_handle} = $dbh;

  # just use our dirname as the path for relative bookfiles
  my $dir = dirname($file);
  $self->set_directory(defined($dir) ? $dir : '.');

  $self->_load_library_info();
  # TODO compare version
  $self->_load_books();
  return $self;
} # end subroutine load_uri definition
########################################################################

# appears to be used only by the test suite -- maybe not a good idea
# TODO use this in our build script?
sub create {
  my $class = shift;
  my ($filename) = @_;

  my $dbh = DBI->connect("dbi:SQLite:$filename", '', '') or
    die "Can't open library database $filename";
  $class->_create_tables($dbh);
}

sub _create_tables {
  my $class = shift;
  my ($dbh) = @_;

  $dbh->do($_) for(
    'CREATE TABLE book ' .
      '(' . join(', ',
        'id varchar(255)',
        'title varchar(255)',
        'uri varchar(255)',
        'type varchar(255)',
        'ordering integer primary key'
        ) .
      ')',
    # let's talk indexes once we have a sensible table
    #'CREATE INDEX book_title ON book (title)',
    #'CREATE INDEX book_uri ON book (uri)',
    'CREATE TABLE library_info (key varchar(255), value varchar(255))',
    "INSERT INTO library_info (key, value) VALUES ('version', '" .
      $class->VERSION . "')",
    "INSERT INTO library_info (key, value) VALUES ('type', '" .
      $class->type . "')",
    #'CREATE INDEX library_info_key ON library_info (key)',
    'CREATE TABLE metadata ' .
      '(' . join(', ',
        'id integer primary key',
        'type varchar(255)',
        'key varchar(255)'
        ) .
      ')',
    'CREATE TABLE metadata_element ' .
      '(' . join(', ',
        'id bigint',
        'key varchar(255)',
        'value varchar(255)'
        ) .
      ')',
    #'CREATE INDEX metadata_element_id ON metadata_element (id, key)',
    # TODO set our current schema version in here
  );
  return;
}


sub _load_books {
  my $self = shift;

  my $dbh = $self->{database_handle};
  my $sth = $dbh->prepare(
    'SELECT id, title, uri, type FROM book ORDER BY ordering'
  );
  $sth->execute();
  my $data = $sth->fetchall_arrayref({});
  $data = [map({dtRdr::LibraryData::BookInfo->new(%$_)} @$data)];
  $self->set_book_data($data);
  return;
}


sub _load_book_objects { # XXX why not in base class?
  my $self = shift;

  my $books = $self->book_data;
  my @book_objs;
  foreach my $bk (@$books) {
    my $type = $bk->type;
    # XXX this should use our $type!
    my $book_obj = dtRdr::Book->new_from_uri($bk->uri);
    push @book_objs, $book_obj;
  }
  $self->{books} = \@book_objs;
}

sub _load_library_info {
  my $self = shift;

  my $dbh = $self->{database_handle};
  $dbh or croak("must have a database_handle");
  my $sth = $dbh->prepare("SELECT key, value FROM library_info");
  $sth->execute();
  my $arrayref = $sth->fetchall_arrayref({});
  foreach my $hashref (@$arrayref) {
    # TODO these should have toplevel accessors
    $self->{library_info}{$hashref->{key}} = $hashref->{value};
  }
}

sub get_info {
  my $self = shift;
  my ($key) = @_;

# XXX ick
  if(exists $self->{library_info}{$key}) {
    return $self->{library_info}{$key};
  }
  else {
    return;
  }
}

sub set_info {
  my $self = shift;
  my ($key, $value) = @_;

  my $dbh = $self->{database_handle};
  if(exists $self->{library_info}{$key}) {
    $dbh->do(
      'UPDATE library_info SET value = ? WHERE key = ?',
      undef, $value, $key
    );
    $self->{library_info}{$key} = $value;
  }
  else {
    $dbh->do(
      'INSERT INTO library_info (key, value) VALUES (?, ?)',
      undef, $key, $value
    );
    $self->{library_info}{$key} = $value;
  }
}


=head2 add_book

  $library->add_book(
    id    => $id,
    title => $title,
    uri   => $uri,
    type  => $type
  );

=cut

sub add_book {
  my $self = shift;
  (@_ % 2) and croak('odd number of elements in argument list');
  my (%data) = @_;

  my $dbh = $self->{database_handle};
  $dbh or croak;
  $dbh->do(
    'INSERT INTO book (id, title, uri, type) VALUES (?, ?, ?, ?)',
    {},
    map({$data{$_}} qw(id title uri type))
  );
  $self->_load_books();
} # end subroutine add_book definition
########################################################################

sub _fetch_all_metadata {
  my $self = shift;

  my $dbh = $self->{database_handle};
  my $base_recs = $dbh->selectall_arrayref("select id, key, type from metadata");
  foreach my $row (@$base_recs) {
    my $id = $row->[0];
    my $metadata = dtRdr::Metadata->new(
      '_library_id' => $row->[0],
      'key'         => $row->[1],
      'type'        => $row->[2]
    );
    my $data_recs = $dbh->selectall_arrayref(
      'SELECT key, value FROM metadata_element WHERE id = ?',
      undef, $id
    );
    foreach my $data_row (@$data_recs) {
      $metadata->add(
        $data_row->[0],
        $metadata->deserialize($data_row->[0], $data_row->[1])
      );
    }
    push(@{$self->{metadata}}, $metadata);
  }
  return(@{$self->{metadata}});
}

# TODO this is just wrong
sub add_metadata {
  my $self = shift;
  my ($metadata) = @_;

  do('./util/BREAK_THIS') or die;

  my $key = $metadata->key();
  my $type = $metadata->type();

  my $dbh = $self->{database_handle};
  $dbh->do(
    'INSERT INTO metadata (key, type) VALUES (?, ?)',
    undef, $key, $type
  );
  my $id = $dbh->func('last_insert_rowid');

  foreach my $element ($metadata->_get_data_elements()) {
    next if $element eq 'key';
    next if $element eq 'type';
    next if $element =~ /^_/;   # Skip any underscore-prefixed things

    my $value = $metadata->get($element);
    if (ref($value) eq 'ARRAY') {
      my (@values) = @$value;
      foreach my $value (@values) {
        $value = $metadata->serialize($element, $value);
        $dbh->do(
          'INSERT INTO metadata_element (id, key, value) VALUES (?,?,?)',
          undef, $id, $element, $value
        );
      }
    }
    else {
      $value = $metadata->serialize($element, $value);
      $dbh->do(
        'INSERT INTO metadata_element (id, key, value) VALUES (?,?,?)',
        undef, $id, $element, $value
      );
    }
  }
  $metadata->set('_library_id', $id);
  if(!defined $self->{metadata}) {
    $self->_fetch_all_metadata();
  }
  else {
    push(@{$self->{metadata}}, $metadata);
  }
}

sub remove_metadata {
  my $self = shift;
  my ($metadata) = @_;

  my $metadata_id = $metadata->get_info('_library_id');
  my $dbh = $self->{database_handle};
  $dbh->do(
    'DELETE FROM metadata_element WHERE id = ?',
    undef, $metadata_id
  );
  $dbh->do(
    'DELETE FROM metadata WHERE id = ?',
    undef, $metadata_id
  );
  undef($$metadata);
}



=head2 find_book_by

Find a book for a given key/value.

  $info = $lib->find_book_by($key, $value);

=cut

sub find_book_by {
  my $self = shift;
  my ($key, $value) = @_;

  my $dbh = $self->{database_handle};
  my $books = $dbh->selectall_arrayref(
    "SELECT uri, type FROM book WHERE $key = ? ORDER BY ordering",
    {Slice => {}},
    $value
  );
  if(@$books == 0) {
    croak("No books matching the $key '$value'");
  }
  elsif(@$books > 1) {
    croak("Too many books matching the $key '$value'");
  }

  return(dtRdr::LibraryData::BookInfo->new(%{$books->[0]}));
} # end subroutine find_book_by definition
########################################################################

=head1 AUTHOR

Dan Sugalski <dan@sidhe.org>

Eric Wilhelm <ewilhelm at cpan dot org>

=head1 COPYRIGHT

Copyright (C) 2006 by Dan Sugalski, Eric L. Wilhelm, and OSoft, All
Rights Reserved.

=head1 NO WARRANTY

Absolutely, positively NO WARRANTY, neither express or implied, is
offered with this software.  You use this software at your own risk.  In
case of loss, no person or entity owes you anything whatsoever.  You
have been warned.

=head1 LICENSE

The dotReader(TM) is OSI Certified Open Source Software licensed under
the GNU General Public License (GPL) Version 2, June 1991. Non-encrypted
and encrypted packages are usable in connection with the dotReader(TM).
The ability to create, edit, or otherwise modify content of such
encrypted packages is self-contained within the packages, and NOT
provided by the dotReader(TM), and is addressed in a separate commercial
license.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

=cut

# vim:ts=2:sw=2:et:sta
1;
