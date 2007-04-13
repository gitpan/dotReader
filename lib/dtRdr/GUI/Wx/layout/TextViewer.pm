package dtRdr::GUI::Wx::layout::TextViewer;
$VERSION = eval{require version}?version::qv($_):$_ for(0.0.1);

use warnings;
use strict;

use Wx ();

use WxPerl::ShortCuts;

use base 'Wx::Frame';

use dtRdr::GUI::Wx::Utils;

=head1 NAME

dtRdr::GUI::Wx::layout::TextViewer - was once autogenerated code

=head1 SYNOPSIS

=cut

=head2 new

Sets some properties, creates child widgets, etc. and calls init().

=cut

sub new {
	my( $class, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef unless defined $parent;
	$id     = -1    unless defined $id;
	$title  = ""    unless defined $title;
	$pos    = DefP  unless defined $pos;
	$size   = Wx::Size->new(600, 320)
                               unless defined $size;
	$name   = ""                 unless defined $name;
  $style = Wx::wxDEFAULT_FRAME_STYLE() unless defined $style;

	my $self = $class->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );

  $self->_create_children;

  $self->__set_properties();
  $self->__do_layout();

  $self->init;
	return $self;
} # end subroutine new definition
########################################################################

# END OF REAL CODE
########################################################################
########################################################################
########################################################################
########################################################################
########################################################################
################ NO MAN'S LAND STARTS HERE #############################
########################################################################
######################### STOP! ########################################
########################################################################
########################################################################
########################################################################
########################################################################




=head2 _create_children

  $self->_create_children;

=cut

sub _create_children {
    my $self = shift;

	use dtRdr::HTMLWidget;
	$self->{html_widget} = dtRdr::HTMLWidget->new($self, -1, DefPS);
	$self->{button_copy_all} = Wx::Button->new($self, -1, "Copy All");
	$self->{button_close} = Wx::Button->new($self, -1, "Close");

} # end subroutine _create_children definition
########################################################################

sub __set_properties {
	my $self = shift;

# THIS IS AUTOGENERATED CODE: {
# begin wxGlade: TextViewer::__set_properties

	$self->SetTitle("Text Viewer");
	my $icon = Wx::Icon->new();
	$icon->CopyFromBitmap(
    dtRdr::GUI::Wx::Utils->Bitmap('frame_icon_text_viewer')
  );
	$self->SetIcon($icon);
	$self->SetSize(Wx::Size->new(640, 320));

# end wxGlade
# THAT WAS AUTOGENERATED CODE }
}

sub __do_layout {
	my $self = shift;

# THIS IS AUTOGENERATED CODE: {
# begin wxGlade: TextViewer::__do_layout

	$self->{grid_sizer_1} = Wx::FlexGridSizer->new(2, 1, 0, 0);
	$self->{grid_sizer_4} = Wx::GridSizer->new(1, 3, 0, 0);
	$self->{grid_sizer_1}->Add($self->{html_widget}, 0, Exp|Ams, 0);
	$self->{grid_sizer_4}->Add(0, 0, 0, Exp, 0);
	$self->{grid_sizer_4}->Add($self->{button_copy_all}, 0, Ams, 0);
	$self->{grid_sizer_4}->Add($self->{button_close}, 0, Ams, 0);
	$self->{grid_sizer_1}->Add($self->{grid_sizer_4}, 1, WX"ALIGN_RIGHT", 0);
	$self->SetAutoLayout(1);
	$self->SetSizer($self->{grid_sizer_1});
	$self->{grid_sizer_1}->AddGrowableRow(0);
	$self->{grid_sizer_1}->AddGrowableCol(0);
	$self->Layout();
	$self->Centre();

# end wxGlade
# THAT WAS AUTOGENERATED CODE }
}

# end of class TextViewer

=head1 AUTHOR

not it

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

# vim:ts=2:sw=2:et:sts=2:sta
