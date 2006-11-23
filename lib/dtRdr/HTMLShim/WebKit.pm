package dtRdr::HTMLShim::WebKit;

use warnings;
use strict;

BEGIN { # TODO fix this
  package Wx::WebKit;
  our @ISA = qw(Wx::ScrolledWindow);
}

use Wx qw(
  :everything
  );
use Wx::WebKit;
use base qw(dtRdr::HTMLWidget);
  sub base { 'Wx::WebKitCtrl' };
#use Wx::Panel;

# TEMPORARY {{{
use dtRdr::Traits::Class qw(
  WARN_NOT_IMPLEMENTED
  );

use dtRdr::HTMLWidget::Shared qw(
  get_scroll_pos
  set_scroll_pos
  scroll_page_down
  scroll_page_up
  jump_to_anchor
); # these are just temporary imports
# TEMPORARY }}}

# webkit can do either absolute links or base64 encoded
use dtRdr::HTMLWidget::Shared;
*img_src_rewrite_sub =
  \&dtRdr::HTMLWidget::Shared::base64_images_rewriter;

=head1 NAME

WebKitShim.pm - the webkit version of the generic html widget

=cut

sub new {
  my $self = shift;
  my (@others) = @_;
  {
    # XXX THE WEBKIT API IS WRONG:
    # the constructor should not need a URL
    warn "FIXME:  WebKit needs hacking";
    splice(@{$others[0]}, 2, 0, "");
  }
  $self = $self->SUPER::new(@others);
  $self->SetBackgroundColour(Wx::Colour->new(244,25,0));
  $self->{load_in_progress} = 0;
  #$self->{webkit} = Wx::WebKitCtrl->new($self, $id, "");
  #$self->{sizer} = Wx::BoxSizer->new(wxVERTICAL);
  #$self->{dummy} = Wx::Panel->new($self, $id);
  #$self->{dummy}->SetBackgroundColour(Wx::Colour->new(0,250, 250));
  #$self->{sizer}->Add($self->{dummy}, 1, wxEXPAND, 0);
  #$self->{sizer}->Add($self->{webkit}, 1, wxEXPAND, 0);
  #$self->{sizer}->Fit($parent);
  #$self->{sizer}->SetSizeHints($parent);
  #$self->SetAutoLayout(1);
  #$self->SetSizer($self->{sizer});
  #$self->Layout();
  return $self;
}

sub init{ # register event handlers
  my ($self,$parent,$htmlwidget) = @_;
}

# XXX this should be in the XS code
sub SetPage { my $self = shift; $self->SetPageSource(@_); }

=head1 AUTHOR

Dan Sugalski <dan@sidhe.org>

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

# vim:ts=2:sw=2:et:sta
1;
