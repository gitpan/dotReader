package dtRdr::Config;

use warnings;
use strict;
use Carp;

# somebody said "use Universal", so bah
sub import {}

# TODO should we let the plugins loader do this:
#use dtRdr::Config::FileConfig;
use dtRdr::Config::SQLConfig;
use dtRdr::Config::YAMLConfig;

use Class::Accessor::Classy;
ro 'location';
rw 'library_data';
no  Class::Accessor::Classy;

{
  package dtRdr::ConfigData::LibraryInfo;
  use Class::Accessor::Classy;
  with 'new';
  ro 'id';
  ro 'uri';
  ro 'type';
  no  Class::Accessor::Classy;
}

=head1 NAME

dtRdr::Config - Factory class for configuration system

=cut

=head1 Factory Methods (er, functions?

=head2 factory_read_config

Constructor function (see new)

  my $obj = factory_read_config($file);

=cut
# TODO: make this a class method new_from_uri()
sub factory_read_config {
  my ($file) = @_;
  $file =~ /^(\w+):(.*)$/;
  my ($type, $fname) = ($1, $2);
  $type or croak("type undefined");

  # TODO replace with plugins code?
  my %dispatch = (
    yaml => 'dtRdr::Config::YAMLConfig',
    file => 'dtRdr::Config::FileConfig',
    remote => sub {
      die "No remote configurations yet";
    },
    sql => 'dtRdr::Config::SQLConfig',
  );

  if(my $res = $dispatch{$type}) {
    ((ref($res) || '') eq 'CODE') and
      return($res->($fname));

    $res->can('read_config') or die "incompetent class:  $res";
    my $conf = $res->new();
    $conf->read_config($fname) or die;
    return($conf);
  }
  else {
    croak("Invalid configuration type $type");
  }
} # end subroutine factory_read_config definition
########################################################################

=head2 new

  $conf = dtRdr::Config->new($file);

=cut
sub new {
  my $package = shift;
  my $caller = caller;
  if(defined($caller) and $caller->isa(__PACKAGE__)) {
    # being inherited => be a base class
    my $class = ref($package) || $package;
    my $self = {@_};
    bless($self, $class);
    return($self);
  }
  else {
    # being called => be a factory
    return(factory_read_config(@_));
  }
} # end subroutine new definition
########################################################################

=head2 get_library_info

  my @libraries = $conf->get_library_info;

=cut

sub get_library_info {
  my $self = shift;
  return(@{$self->library_data});
} # end subroutine get_library_info definition
########################################################################

=head1 AUTHOR

Dan Sugalski, <dan@sidhe.org>

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

1;
# vim:ts=2:sw=2:et:sta
