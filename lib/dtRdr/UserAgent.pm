package dtRdr::UserAgent;
$VERSION = eval{require version}?version::qv($_):$_ for(0.0.1);

use warnings;
use strict;
use Carp;

use base 'LWP::Iterator::UserAgent';

my @subs = qw(
  progress_sub
  collect_sub
  connect_sub
  failure_sub
  return_sub
);

use Class::Accessor::Classy;
rw @subs;
ro 'data';
no  Class::Accessor::Classy;

=head1 NAME

dtRdr::UserAgent - Custom LWP::Iterator::UserAgent

=head1 SYNOPSIS

=cut


=head2 new

  my $ua = dtRdr::UserAgent->new('GET', $url);

=cut

sub new {
  my $class = shift;
  (@_ %2) and croak("odd number of elements in argument hash");
  my ($method, $url) = (shift(@_), shift(@_));
  my $self = $class->SUPER::new(@_);

  $self->{data} = '';
  $self->{deadline} ||= 5;
  $self->timeout(0.1);
  $self->redirect(1);
  $self->{$_} = sub {} for(@subs);
  $self->register(
    HTTP::Request->new($method, $url),
    sub { $self->on_collect(@_); }
  );

  return($self);
} # end subroutine new definition
########################################################################

=head2 on_collect

  $ua->on_collect;

=cut

sub on_collect {
  my $self = shift;
  return(undef);
} # end subroutine on_collect definition
########################################################################

=head2 on_connect

  $ua->on_connect;

=cut

sub on_connect {
  my $self = shift;
  return(undef);
} # end subroutine on_connect definition
########################################################################

=head2 on_failure

  $ua->on_failure;

=cut

sub on_failure {
  my $self = shift;
  return(undef);
} # end subroutine on_failure definition
########################################################################

=head2 on_return

  $ua->on_return;

=cut

sub on_return {
  my $self = shift;
  return(undef);
} # end subroutine on_return definition
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

