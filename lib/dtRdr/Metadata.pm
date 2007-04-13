package dtRdr::Metadata;
$VERSION = eval{require version}?version::qv($_):$_ for(0.0.1);

use warnings;
use strict;

=head1 NAME

dtRdr::Metadata - arbitrary metadata

=head1 SYNOPSIS

This module is scheduled to get some nice concrete boots and a trip to
the lake.

=head1 Bah

None of this is quite right, but it also has no pod, so I'm just going
to list them.

=over

=item  book

=item  get

=item  has_item

=item  library

=item  matches

=item  name

=item  new

=item  set

=item  set_book

=item  set_library

=item  type

=back

=cut

sub new { # XXX fix this constructor
  my ($self, %keyval) = @_;
  return bless \%keyval;
}

sub has_item {
  my $self = shift;
  my ($item) = @_;
  return exists $self->{$item};
}

sub set {
  my ($self, $key, $value) = @_;
  $self->{$key} = $value;
}

sub get {
  my ($self, $key) = @_;
  return $self->{$key};
}

sub set_library {
  my ($self, $library) = @_;
  $self->{library} = $library;
}

sub set_book {
  my ($self, $book) = @_;
  $self->set('book', $book);
}

sub name {
  my $self = shift;
  return $self->{name};
}

sub type {
  my $self = shift;
  return $self->{type};
}

sub book {
  my $self = shift;
  return $self->get('book');
}

sub library {
  my $self = shift;
  return $self->{library};
}


=head2 add

Add a new value for a key in a metadata object. If there's already a
value for that named key this is added to it, making the value an
array of values if it wasn't already.

  $meta->add(name, value);

=cut

sub add {
  my ($self, $key, $value) = @_;
  if (!exists $self->{$key}) {
    $self->{$key} = $value;
  } elsif (ref($self->{$key}) eq 'ARRAY') {
    push @{$self->{$key}}, $value;
  } else {
    my $arr = [$self->{$key}, $value];
    $self->{$key} = $arr;
  }
}

=head2 serialize

Takes an element name and a value for that element and returns a
serializable version of that value

  $meta->serialize($element, $value);

=cut

sub serialize {
  my ($self, $key, $value) = @_;
  return $value;
}

=head2 deserialize

Take an element name and a serialized value for that element and
reconstitute the object for that element.

  $meta->deserialize($element, $value);

=cut

sub deserialize {
  my ($self, $key, $value) = @_;
  return $value;
}

sub _get_data_elements {
  my ($self) = shift;
  return(keys %$self);
}

sub matches {
  my ($self, %things) = @_;
  foreach my $key (keys %things) {
    if (!exists $self->{$key}) {
      return 0;
    }
    if ($self->{$key} ne $things{$key}) {
      return 0;
    }
  }
  return 1;
}

=head2 within

Returns true if the metadata element contains the point. Metadata
elements with no range attached will return false, as will elements in
a different book.

  $meta->within($point);

=cut

sub within {
  my ($self, $location) = @_;

  # YAGNI YAGNI YAGNI YAGNI YAGNI YAGNI YAGNI YAGNI
  # XXX if anything, this would just be
  #   $location->is_within($range);
  # or
  #   $range->does_contain($location);

  do('./util/BREAK_THIS') or die;

  my $within = 0;
  if (!exists $self->{range}) {
    return 0;
  }
  my $range = $self->{range};
  my $from = $range->start();
  my $to = $range->end();
  # If everything's got the same base, skip transforms and just check
  # the location offsets
  if ($from->base_loc() eq $to->base_loc() &&
      $from->base_loc() eq $location->base_loc()) {
    my $check = $location->offset();
    my $start = $from->offset();
    if ($start > $check) {
      return 0;
    }
    my $end = $to->offset();
    if ($end < $check) {
      return 0;
    }
    return 1;
  } else {
    my $check = $location->absolute();
    my $start = $from->absolute();
    if ($check < $start) {
      return 0;
    }
    my $end = $to->absolute();
    if ($check > $end) {
      return 0;
    }
    return 1;
  }
}

=head1 AUTHOR

Dan Sugalski, Gary Varnell

=head1 COPYRIGHT

Copyright (C) 2006 OSoft, All Rights Reserved.

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
