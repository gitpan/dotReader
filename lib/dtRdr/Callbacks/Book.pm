package dtRdr::Callbacks::Book;

use warnings;
use strict;

our $VERSION = '0.01';

use dtRdr::Accessor;
dtRdr::Accessor->rw qw(
  img_src_rewrite
  core_link
);
dtRdr::Accessor->ro qw(
  html_head_append
);

=head1 NAME

dtRdr::Callbacks::Book - the callbacks object for books

=head1 SYNOPSIS

  my $callbacks = dtRdr::Callbacks::Book->new();
  $callbacks->set_core_link(sub {"foo://" . $_[0]});

  # later ...

  my $link = $callback->core_link($book, 'dr_note_link.png');

=cut

my %defaults; # will hold default subs for undeclared stuff

=head2 new

Might take arguments later, but not yet.

  my $callbacks = dtRdr::Callbacks::Book->new();

=cut

sub new {
  my $package = shift;
  my $class = ref($package) || $package;
  my $self = {
    # list-types should be predeclared?
    html_head_append => [],
  };
  bless($self, $class);
  return($self);
} # end subroutine new definition
########################################################################

=head1 Callbacks

The documentation for each callback here should also serve as your
custom callback's prototype template.

=head2 core_link

Create a uri to a core file (such as an icon.)  The default is to
prepend 'dr://CORE/'.

  my $link = $callbacks->core_link($item);

=cut

$defaults{core_link} = sub {
  my ($item) = @_;
  return('dr://CORE/' . $item);
};

sub core_link {
  my $self = shift;
  my $subref = $self->get_core_link || $defaults{core_link};
  return($subref->(@_));
} # end subroutine core_link definition
########################################################################

=head2 set_core_link

Only once.

  $callbacks->set_core_link($subref);

=cut

sub set_core_link {
  my $self = shift;
  my ($subref) = @_;

  # once and only once
  $self->get_core_link and
    croak("attempt to redefine 'core_link' callback");

  $self->SUPER::set_core_link($subref);
} # end subroutine set_core_link definition
########################################################################


=head2 img_src_rewrite

  my $uri = $callbacks->img_src_rewrite($src, $book);

=cut

$defaults{img_src_rewrite} = sub {
  my ($src, $book) = @_;
  return($src);
};

sub img_src_rewrite {
  my $self = shift;
  my $subref = $self->get_img_src_rewrite || $defaults{img_src_rewrite};
  return($subref->(@_));
} # end subroutine img_src_rewrite definition
########################################################################

=head2 set_img_src_rewrite

  $callbacks->set_img_src_rewrite($subref);

=cut

sub set_img_src_rewrite {
  my $self = shift;
  my ($subref) = @_;

  # once and only once
  $self->get_img_src_rewrite and
    croak("attempt to redefine 'img_src_rewrite' callback");

  $self->SUPER::set_img_src_rewrite($subref);
} # end subroutine set_img_src_rewrite definition
########################################################################

=head1 TODO

  $callbacks->add_html_head_append($subref);

=cut

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
