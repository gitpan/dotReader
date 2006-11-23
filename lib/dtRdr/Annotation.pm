package dtRdr::Annotation;

use warnings;
use strict;

our $VERSION = '0.01';

use dtRdr::Traits::Class qw(claim);

# yay! we can't do this here because of MI and Class::Accessor::new()
use Class::Accessor::Classy;
ro 'is_fake';
no  Class::Accessor::Classy;

=head1 NAME

dtRdr::Annotation - base class for Note, Bookmark, and Highlight objects

=head1 SYNOPSIS

Not much happening here.  See L<dtRdr::Annotation::Range>.

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
