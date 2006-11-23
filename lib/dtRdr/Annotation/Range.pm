package dtRdr::Annotation::Range;

use warnings;
use strict;
use Carp;

our $VERSION = '0.01';

use base 'dtRdr::Annotation';
use base 'dtRdr::Selection';

use Class::Accessor::Classy;
rw 'title';
no  Class::Accessor::Classy;

{
  package dtRdr::AnnoSelection;
  our @ISA = qw(dtRdr::Annotation::Range);
}

=head1 NAME

dtRdr::Annotation::Range - range-derived annotations

=head1 SYNOPSIS

=cut

=head2 renode

  $hl->renode($node, %props);

=cut

sub renode {
  my $self = shift;
  my $node = shift;
  (@_ % 2) and croak('odd number of elements in argument hash');
  my %props = @_;

  my $package = ref($self);
  return($package->create(
    range => $self,
    %props,
    id => $self->id,
    node => $node,
    is_fake => 1, # always set this
  ));
} # end subroutine renode definition
########################################################################

=head2 get_book

Overrides the range get_book alias.

  $hl->get_book;

=cut

sub get_book {
  my $self = shift;
  $self->node->book;
} # end subroutine get_book definition
########################################################################

=head1 Serialization

=head2 serialize

  my $plain_hashref = $hl->serialize;

=cut

sub _IF_CANS () {qw(content title selected context)};
sub serialize {
  my $self = shift;
  $self->is_fake and croak("cannot serialize a fake (localized) annotation");
  my $lsub = sub {
    my $foo = shift;
    return($foo->offset);
  };
  my %serializer = (
    book  => sub { my $foo = shift; $foo->id; },
    node  => sub { my $foo = shift; $foo->id; },
    start => $lsub,
    end   => $lsub,
    id    => sub {$_[0]}, # by definition
  );

  my %hash = map({$_ => $serializer{$_}->($self->$_)}
    qw(book node start end id)
  );

  # some special cases
  foreach my $attribute (_IF_CANS) {
    if($self->can($attribute)) {
      $hash{$attribute} = $self->$attribute;
    }
  }

  # and remember our type
  $hash{type} = ref($self);

  return(\%hash);
} # end subroutine serialize definition
########################################################################

=head2 deserialize

Transform the stripped-down hashref (as returned by serialize()) into a
proper object.

  my $hl = dtRdr::Highlight->deserialize($hashref, book => $book);

=cut

sub deserialize {
  my $package = shift;
  my ($hashref, @args) = @_;
  (@args % 2) and croak('odd number of elements in argument hash');
  my %args = @args;

  (ref($hashref) || '' eq 'HASH') or
    croak("'$hashref' is not a hash reference");

  my $book = $args{book};
  defined($book) or croak("must have a book");
  ($hashref->{book} eq $book->id) or croak("wrong book");

  my $node = $hashref->{node};
  defined($node) or die;
  $node = $book->toc->get_by_id($node);
  defined($node) or die;

  my $object = $package->create(
    map({
      ($package->can($_) ? ($_ => $hashref->{$_}) : ())
    } _IF_CANS
    ),
    node  => $node,
    range => [$hashref->{start}, $hashref->{end}],
    id    => $hashref->{id}
  );
  return($object);
} # end subroutine deserialize definition
########################################################################

=head2 clone

Creates a (mostly) detatched version of the object.  (use sparingly)

  $obj->clone;

=cut

sub clone {
  my $self = shift;
  my $clone = ref($self)->deserialize(
    $self->serialize, book => $self->book
  );
  return($clone);
} # end subroutine clone definition
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
