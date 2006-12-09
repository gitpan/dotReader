package dtRdr::Annotation::IO::YAML;

use warnings;
use strict;
use Carp;

use YAML::Syck;

our $VERSION = '0.01';

use base 'dtRdr::Annotation::IO';

=head1 NAME

dtRdr::Annotation::IO::YAML - read/write annotations from/to yml files

=head1 SYNOPSIS

=cut

=head1 Methods

=head2 init

  $io->init;

=cut

sub init {
  my $self = shift;

  my $uri = $self->uri or croak("must have uri");

  # fixup
  $uri =~ s#/*$#/#;
  $self->{uri} = $uri;

  if(-e $uri) {
    (-d $uri) or croak("'$uri' is not a directory");
  }
  else {
    # XXX too dwim?
    mkdir($uri) or die "cannot create $uri";
  }

  my $store = $self->{_store} = {};
  # to slurp-in all of the files now or read them individually later?
  {
    opendir(my $dh, $uri) or die;
    my @files = grep(/\.yml$/, readdir($dh));
    foreach my $file (@files) {
      my $filename = $uri . $file;
      $file =~ s/\.yml$// or die;
      my $data = YAML::Syck::LoadFile($filename);
      defined($data) or die "oops";
      $store->{$file} = $data;
    }
  }
} # end subroutine init definition
########################################################################

=head2 items_for

Return the hashrefs for a given book.

  @items = $io->items_for($book);

=cut

sub items_for {
  my $self = shift;
  my ($obj) = @_;

  # TODO parametric polymorphism
  eval {$obj->isa('dtRdr::Book')} or die "I only do books";

  my $want_id = $obj->id;
  defined($want_id) or croak("object '$obj' must have an id");

  grep({$_->{book} eq $want_id} values(%{$self->{_store}}));
} # end subroutine items_for definition
########################################################################


=head2 insert

  $io->insert($object, %args);

=cut

sub insert {
  my $self = shift;
  my ($obj) = @_;
  $obj->can('serialize') or croak("$obj won't work");

  # get a plain hashref
  my $data = $obj->serialize;
  0 and warn "got:\n", YAML::Syck::Dump($data), "\n ";

  my $id = $data->{id};

  # an in-memory cache too -- means we don't have to go away, come back
  $self->{_store}{$id} and croak("duped id? -- $id");
  $self->{_store}{$id} = $data;

  my $filename = $self->uri . $id . '.yml';
  (-e $filename) and croak("duped id? -- $filename exists");
  YAML::Syck::DumpFile($filename, $data) or die;
} # end subroutine insert definition
########################################################################


=head2 delete

  $io->delete($object, %args);

=cut

sub delete {
  my $self = shift;
  my ($obj) = @_;

  my $id = $obj->id;
  $self->{_store}{$id} or croak("cannot delete -- nothing for $id");
  delete($self->{_store}{$id});

  my $filename = $self->uri . $id . '.yml';
  (-e $filename) or croak("no file to delete -- $filename");
  unlink($filename) or die;
} # end subroutine delete definition
########################################################################

=head2 update

  $io->update($object, %args);

=cut

sub update {
  my $self = shift;
  my ($obj) = @_;
  $obj->can('serialize') or croak("$obj won't work");

  my $id = $obj->id;

  # get a plain hashref
  my $data = $obj->serialize;

  # an in-memory cache too -- means we don't have to go away, come back
  $self->{_store}{$id} or croak("cannot update -- nothing for $id");
  $self->{_store}{$id} = $data;

  my $filename = $self->uri . $id . '.yml';
  (-e $filename) or croak("cannot update -- $filename does not exist");
  YAML::Syck::DumpFile($filename, $data) or die;
} # end subroutine update definition
########################################################################

=head1 AUTHOR

Eric Wilhelm <ewilhelm at cpan dot org>

http://scratchcomputing.com/

=head1 COPYRIGHT

Copyright (C) 2006 Eric L. Wilhelm and Osoft, All Rights Reserved.

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
