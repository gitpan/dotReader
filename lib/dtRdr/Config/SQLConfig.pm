package dtRdr::Config::SQLConfig;
$VERSION = eval{require version}?version::qv($_):$_ for(0.0.1);

# An SQLite based configuration system

use warnings;
use strict;

use DBI;

use base 'dtRdr::Config';
use dtRdr::Config (
  register => {},
);

use constant {
  DEBUG => 0,
};

=head1 NAME

dtRdr::Config::SQLConfig - a config file stored in SQLite

=head1 SYNOPSIS

This module is scheduled to get some nice concrete boots and a trip to
the lake.

=cut

=head1 ABOUT

Not intended to be instantiated directly.

Use the dtRdr::Config factory class.

=head2 read_config

=cut

sub read_config {
  my $self = shift;
  my ($filename) = @_;

  my $dbh;
  DEBUG and warn "opening config $filename";

  if (!-e $filename) {
    $dbh = _create_new_configdb($filename);
  }
  else {
    $dbh = DBI->connect("dbi:SQLite:$filename","","") or
      die "Can't open library database $filename";
  }
  $self->{location} = $filename;
  $self->{dbh} = $dbh;
  $self->_load_userinfo;
  $self->_load_modules;
  # XXX these need work
  #$self->_load_libraryhandlers;
  #$self->_load_bookhandlers;
  # $self->_load_libraries;
  #$self->_load_crypto;
  return $self;
}

# XXX be add_library()
# XXX and more of the same for the rest of you's
sub insert_library {
  my ($self, $name, $type) = @_;
  $self->{dbh}->do("insert into library (name, type) values (?, ?)", {}, $name, $type);
}

sub insert_module {
  my ($self, $modulename, $order) = @_;
  if (defined $order && $order) {
    $self->{dbh}->do("insert into module (modulename, ordering) values (?, ?)", {}, $modulename, $order);
  } else {
    $self->{dbh}->do("insert into module (modulename) values (?)", {}, $modulename);
  }
}

sub insert_bookhandler {
  my ($self, $type, $handler_name) = @_;
  $self->{dbh}->do("insert into book_handler (type, routine) values (?, ?)", {}, $type, $handler_name);
}

sub insert_libraryhandler {
  my ($self, $type, $handler_name) = @_;
  $self->{dbh}->do("insert into library_handler (type, routine) values (?, ?)", {}, $type, $handler_name);
}

sub insert_userinfo {
  my ($self, $key, $value) = shift;
  my $dbh = $self->{dbh};
  $dbh->do("insert into userinfo (key, value) values (?, ?)", undef, $key, $value);
}

=begin TODO

(I guess)

  insert_crypto
  remove_library
  remove_module
  remove_bookhandler
  remove_libraryhandler
  remove_crypto
  move_library
  move_module
  move_bookhandler
  move_libraryhandler
  move_crypto

=end TODO

=cut

sub remove_userinfo {
  my ($self, $key) = @_;
  my $dbh = $self->{dbh};
  $dbh->do("delete from userinfo where key = ?", undef, $key);
}

sub list_modules {
  my $self = shift;
  my $dbh = $self->{dbh};
  my $rows = $dbh->selectall_arrayref(
    "select modulename from module order by ordering"
  );
  my @modules;
  foreach my $row (@$rows) {
    push @modules, $row->[0];
  }
  return @modules;
}

sub list_library_handlers {
  my $self = shift;
  my $dbh = $self->{dbh};
  my $rows = $dbh->selectall_arrayref(
    "select type, routine from library_handler"
  );
  return @$rows;
}

sub list_book_handlers {
  my $self = shift;
  my $dbh = $self->{dbh};
  my $rows = $dbh->selectall_arrayref("select type, routine from book_handler");
  return @$rows;
}

sub _create_new_configdb {
  my $filename = shift;
  my $dbh = DBI->connect("dbi:SQLite:$filename","","") or
    die "Can't open library database $filename";
  $dbh->do("create table userinfo (key varchar(255), value varchar(255))");
  $dbh->do("create table module (modulename varchar(255), ordering integer primary key)");
  $dbh->do("create table book_handler (type varchar(255), routine varchar(255))");
  $dbh->do("create table library (type varchar(255), name varchar(255), ordering integer primary key)");
  $dbh->do("create table library_handler (type varchar(255), routine varchar(255))");
  $dbh->do("create table filters (type varchar(255), name varchar(255), ordering integer primary key)");
  $dbh->do("create table crypto (generic_data varchar(255), ordering integer primary key)");
  return $dbh;

}

sub _load_userinfo {
  my $self = shift;
  my $dbh = $self->{dbh};
  my $sth = $dbh->prepare("select key, value from userinfo");
  $sth->execute();
  my $userinfo = $sth->fetchall_arrayref();
  foreach my $info (@$userinfo) {
    # XXX condescending
    $self->{user}->_set_info_noupdate($info->[0], $info->[1]);
  }
}

sub _load_modules {
  my $self = shift;

  # XXX what? why?

  my $dbh = $self->{dbh};
  my $sth = $dbh->prepare("select modulename from module order by ordering");
  $sth->execute();
  my $modules = $sth->fetchall_arrayref();
  foreach my $module (@$modules) {
    my $modulename = $module->[0];
    eval "use $modulename";
    if ($@) {
      die "can't use module $modulename, error $@";
    }
  }
}

sub _load_libraryhandlers {
  my $self = shift;
  die;
  my $dbh = $self->{dbh};
  my $sth = $dbh->prepare("select type, routine from library_handler");
  $sth->execute();
  my $libraries = $sth->fetchall_arrayref();
  foreach my $library (@$libraries) {
    # XXX quit twiddling plugins from here
    # dtRdr::Plugins::set_handler(LIBRARY, $library->[0], $library->[1]);
  }
}

sub _load_bookhandlers {
  my $self = shift;
  die;
  my $dbh = $self->{dbh};
  my $sth = $dbh->prepare("select type, routine from book_handler");
  $sth->execute();
  my $books = $sth->fetchall_arrayref();
  foreach my $book (@$books) {
    # XXX quit twiddling plugins from here
    # dtRdr::Plugins::set_handler(BOOK_READER, $book->[0], $book->[1]);
  }
}

sub list_libraries {
  my $self = shift;
  my $sth = $self->{dbh}->prepare(
    "select name, type from library order by ordering"
  );
  $sth->execute();
  my $libraries = $sth->fetchall_arrayref();
  $libraries or die;
  return(@$libraries);
}

sub _load_libraries {
  my $self = shift;
  warn "_load_libraries is useless";
  return;

  my $dbh = $self->{dbh};
  my $user = 'meh'; # $self->{user};
  my $sth = $dbh->prepare("select type, name from library order by ordering");
  $sth->execute();
  my $libraries = $sth->fetchall_arrayref();
  foreach my $library (@$libraries) {
      my ($lib_type, $lib_name) = @$library;
      # XXX what's a handler?  we want a class
      # $lib_type->new ?
      # my $type = dtRdr::Library->class_by_type($type);
      my $lib_handler = '';#dtRdr::Plugins::get_handler(LIBRARY, $lib_type);
      my $library_object = $lib_handler->($lib_name);

      # XXX don't be condescending to the user object
      $user->_add_library_noupdate($library_object);
  }
}

=head1 AUTHOR

Dan Sugalski <dan@sidhe.org>

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

1;
# vim:ts=2:sw=2:et:sta
