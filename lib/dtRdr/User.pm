package dtRdr::User;

use warnings;
use strict;

use Carp;

use dtRdr;
use dtRdr::Config;
use dtRdr::Library;

use Class::Accessor::Classy;
ro 'config';
no  Class::Accessor::Classy;

=head1 NAME

dtRdr::User.pm - user class

=cut

# TODO most of the user and config stuff is just hobbling along at the
# moment and could really use a rethink.

=head1 Constructor

=head2 new

  $user = dtRdr::User->new($username);

=cut
sub new {
  my $package = shift;
  my ($username) = @_;
  #$username or carp("null username");

  my $class = ref($package) || $package;
  my $self = {
    libraries => [],
    info => {},
    username => $username,
    #directory => XXX ?
  };
  bless($self, $class);

  # my $filename = "file:drconfig";
  # XXX MAYBE better than reworking SQLConfig?
  # XXX we should stop doing this prefix thing
  my $filename = 'yaml:' . dtRdr->user_dir . 'drconfig.yml';
  #my $filename = 'sql:' . dtRdr->user_dir . 'drconfig.db';

  $self->init_config($filename);

  # dtRdr::Plugins->init($config); # ?

  return($self);
} # end subroutine new definition
########################################################################

=head1 Methods

=head2 init_config

  $user->init_config($filename);

=cut

sub init_config {
  my $self = shift;
  my ($filename) = @_;

  $filename or croak("must have a filename");
  $self->{config} and croak("can only init once");

  my $config = $self->{config} = dtRdr::Config->new($filename);

  my @libraries = $config->get_library_info;

  # XXX why?
  foreach my $info (@libraries) {
    # lookup the type
    my $library_class = dtRdr::Library->class_by_type($info->type);
    my $library = $library_class->new();
    $library->load_uri(dtRdr->user_dir . $info->uri); # XXX shouldn't be here?
    $self->_add_library_noupdate($library);
  }
  1;
} # end subroutine init_config definition
########################################################################

# Add a library to the current list of libraries the user has open
sub add_library { # XXX why?
  my $self = shift;
  my ($lib) = @_;

  my ($libname, $libtype) = ($lib->location, $lib->handler);
  do('./util/BREAK_THIS') or die;
  $self->config->insert_library($libname, $libtype);
  $self->_add_library_noupdate($lib);
}

sub _add_library_noupdate {
  my $self = shift;
  my ($lib) = @_;

  push @{$self->{libraries}}, $lib;
}

sub get_libraries {
  my $self = shift;

  return @{$self->{libraries}};
}

sub set_info {
  my $self = shift;
  my ($thing, $value) = @_;

  if (exists $self->{info}{lc $thing}) {
    $self->{config}->delete_userinfo(lc $thing);
  }
  $self->{config}->insert_userinfo(lc $thing, $value);
  $self->_set_info_noupdate($thing, $value);
}

sub _set_info_noupdate {
  my $self = shift;
  my ($thing, $value) = @_;

  $self->{info}{lc $thing} = $value;
}


sub get_info {
  my $self = shift;
  my ($thing) = @_;

  return $self->{info}{lc $thing};
}

sub username { # XXX accessor
  my $self = shift;
  return $self->{username};
}

sub add_module { # XXX why?
  my $self = shift;
  my ($modulename) = @_;

  $self->{config}->insert_module($modulename);
}

sub list_modules { # XXX why?
  my $self = shift;
  return $self->{config}->list_modules();
}

sub add_library_handler { # XXX why?
  my $self = shift;
  my ($type, $handler_name) = @_;
  $self->{config}->insert_libraryhandler($type, $handler_name);
}

sub list_library_handlers { # XXX why?
  my $self = shift;
  return $self->{config}->list_library_handlers();
}

sub add_book_handler { # XXX why?
  my $self = shift;
  my ($type, $handler_name) = @_;

  $self->{config}->insert_bookhandler($type, $handler_name);
}

sub list_book_handlers { # XXX why?
  my $self = shift;

  return $self->{config}->list_book_handlers();
}

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
