package dtRdr::Config::YAMLConfig;

use warnings;
use strict;
use Carp;

our $VERSION = '0.01';

use base 'dtRdr::Config';
use dtRdr::Config (
  register => {
    type => 'YAMLConfig'
  },
);
sub type {'YAMLConfig';} # needs to go away when plugins work?

use YAML::Syck qw(
  LoadFile
  DumpFile
);

=head1 NAME

dtRdr::Config::YAMLConfig - a config file

=head1 SYNOPSIS

=cut


=head2 create

  dtRdr::Config::YAMLConfig->create($filename);

=cut

sub create {
  my $package = shift;
  my ($file) = @_;
  my %data = (
    version      => $package->VERSION . '', # ensure stringification
    user_info    => {},
    module       => [], # XXX probably not
    book_handler => {}, # XXX doubtful
    library      => [],
  );
  DumpFile($file, \%data);
} # end subroutine create definition
########################################################################
sub _ylibraries { $_[0]->{yml}{library};}


=head2 read_config

  $conf->read_config($uri);

=cut

sub read_config {
  my $self = shift;
  my ($filename) = @_;

  if (!-e $filename) {
    $self->create($filename);
  }

  $self->{location} = $filename;
  $self->_load;
} # end subroutine read_config definition
########################################################################

=head2 _dumpload

Ensure that the on-disk and in-memory data are in sync.

  $self->_dumpload;

=cut

sub _dumpload {
  my $self = shift;
  $self->_dump;
  $self->_load;
} # end subroutine _dumpload definition
########################################################################

=head2 _dump

  $self->_dump;

=cut

sub _dump {
  my $self = shift;
  DumpFile($self->location, $self->{yml});
} # end subroutine _dump definition
########################################################################

=head2 _load

  $self->_load;

=cut

sub _load {
  my $self = shift;
  $self->{yml} = LoadFile($self->location);
} # end subroutine _load definition
########################################################################

=head2 add_library

  my $id = $conf->add_library(type => $type, uri => $uri);

=cut

sub add_library {
  my $self = shift;
  (@_ % 2) and croak('odd number of elements in argument list');
  my (%data) = @_;

  my $L = $self->_ylibraries;
  if(defined(my $id = delete($data{id}))) {
    ($id == @$L) or croak("cannot use id '$id'");
  }

  exists($data{$_}) or croak("must have field $_") for(qw(uri type));
  my $v = push(@$L, \%data) - 1;

  $self->_dumpload;
  return($v);
} # end subroutine add_library definition
########################################################################

=head2 library_data

  $conf->library_data;

=cut

sub library_data {
  my $self = shift;

  my $L = $self->_ylibraries;
  # TODO make those persistent objects
  return([map({
    dtRdr::ConfigData::LibraryInfo->new(%{$L->[$_]}, id => $_)
  } 0..$#$L)]);
} # end subroutine library_data definition
########################################################################




=head1 AUTHOR

Eric Wilhelm <ewilhelm at cpan dot org>

http://scratchcomputing.com/

=head1 COPYRIGHT

Copyright (C) 2006 Eric L. Wilhelm and OSoft, All Rights Reserved.

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

# vi:ts=2:sw=2:et:sta
1;
