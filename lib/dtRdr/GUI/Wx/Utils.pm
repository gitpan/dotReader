package dtRdr::GUI::Wx::Utils;
$VERSION = eval{require version}?version::qv($_):$_ for(0.10.1);

use warnings;
use strict;
use Carp;

use Wx ();
use Wx::Event ();


=head1 NAME

dtRdr::GUI::Wx::Utils - wx shortcut functions

=head1 SYNOPSIS

=cut

BEGIN {
  use Exporter;
  *{import} = \&Exporter::import;
  our @EXPORT_OK = qw(
    _accel
  );
}


=head2 _accel

Create an EVT_MENU with a Wx::NewId

  $handler->_accel($stroke, $subref);

Returns an array ref suitable for Wx::AcceleratorTable->new.

=cut

sub _accel {
  my $self = shift;
  my ($stroke, $subref) = @_;

  defined($stroke) or croak("must have keystroke");
  my $mod = 0;
  while($stroke =~ s/^([^\+]+)\+//) {
    my $mk = 'wxACCEL_' . $1;
    Wx->can($mk) or croak("cannot find modifier key $mk");
    $mod |= Wx->$mk;
  }

  my $key = $stroke;
  my $kl = length($key);
  $kl or croak("keystroke invalid ('PLUS'?)");
  if($kl > 1) {
    # it's a constant
    my $key_const = 'WXK_' . $key;
    Wx->can($key_const) or croak("cannot find key constant $key_const");
    $key = Wx->$key_const;
  }
  else {
    # it's a letter
    $key = ord(uc($key));
  }

  unless(ref($subref)) { # it's a method
    my $method = $subref;
    $subref = sub {$_[0]->$method($_[1])};
  }

  my $id = Wx::NewId;
  Wx::Event::EVT_MENU($self, $id, $subref);
  return([$mod, $key, $id]);
} # end subroutine _accel definition
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
