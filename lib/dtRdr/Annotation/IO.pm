package dtRdr::Annotation::IO;
$VERSION = eval{require version}?version::qv($_):$_ for(0.10.1);

use warnings;
use strict;
use Carp;


use dtRdr::Accessor;
dtRdr::Accessor->ro qw(
  uri
);

=head1 NAME

dtRdr::Annotation::IO - Base class for annotation I/O

=head1 SYNOPSIS

  use dtRdr::Annotation::IO;
  my $anno_io = dtRdr::Annotation::IO->new(uri => $directory);
  $anno_io->apply_to($book);

=cut

=head2 new

Constructor / Factory method.

  dtRdr::Annotation::IO->new(uri => $uri);

=cut

sub new {
  my $package = shift;
  (@_ % 2) and croak('odd number of elements in argument list');
  my (%args) = @_;

  my $caller = caller;

  if(defined($caller) and $caller->isa(__PACKAGE__)) {
    # constructor
    my $self = {%args};
    bless($self, $package);

    # let it setup itself
    $self->init;

    return($self);
  }
  else {
    # be a factory
    my $uri = $args{uri};
    defined($uri) or croak("cannot dispatch without uri argument");
    my $class = $package->class_for($args{uri});
    $class->new(%args);
  }
} # end subroutine new definition
########################################################################

=head2 class_for

  dtRdr::Annotation::IO->class_for($uri);

=cut

sub class_for {
  my $package = shift;
  my ($uri) = @_;
  # TODO either plugins or maybe just leave hardcoded for now
  use dtRdr::Annotation::IO::YAML;
  return('dtRdr::Annotation::IO::YAML'); # easy answer
} # end subroutine class_for definition
########################################################################

=head1 Methods

TODO/subclasses
$io->init;
$io->insert($object, %args);
$io->delete($object, %args);
$io->update($object, %args);

=head2 apply_to

  $io->apply_to($book);

=cut

sub apply_to {
  my $self = shift;
  my ($book) = @_;

  $book->anno_io and croak("that's going to hurt");

  foreach my $item ($self->items_for($book)) {
    my $type = $item->{type};

    { # long form of require
      my $type_pm = $type;
      $type_pm =~ s#::#/#g;
      $type_pm .= '.pm';
      eval { require "$type_pm" };
      $@ and croak("bah $@");
    }

    my $object = $type->deserialize($item, book => $book);

    # XXX if subclassing, we'll have to loop over $type's @ISA ?
    my $addtype = {
      'dtRdr::Highlight' => 'highlight',
      'dtRdr::Bookmark'  => 'bookmark',
      'dtRdr::Note'      => 'note',
    }->{$type};
    $addtype or die "$type breaks me here";

    my $method = "add_$addtype";
    $book->$method($object);
  }

  $book->set_anno_io($self);

} # end subroutine apply_to definition
########################################################################



=head1 AUTHOR

Eric Wilhelm <ewilhelm at cpan dot org>

http://scratchcomputing.com/

=head1 BUGS

If you found this module on CPAN, please report any bugs or feature
requests through the web interface at L<http://rt.cpan.org>.  I will be
notified, and then you'll automatically be notified of progress on your
bug as I make changes.

If you pulled this development version from my /svn/, please contact me
directly.

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
