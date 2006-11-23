package dtRdr::GUI::Wx::MainFrame;

use strict;
use warnings;

use Wx qw(
  :everything
);

use base qw(dtRdr::GUI::Wx::Frame);
use dtRdr::GUI::Wx::NoteViewer;
use dtRdr::GUI::Wx::Sidebar;
use dtRdr::GUI::Wx::BVManager;

# THIS IS AUTOGENERATED CODE: {
# begin wxGlade: ::dependencies
# end wxGlade
# THAT WAS AUTOGENERATED CODE }


=head1 NAME

dtRdr::GUI::Wx::MainFrame - autogenerated code

=head1 SYNOPSIS

This module is scheduled to get some nice concrete boots and a trip to
the lake.

=cut

=head2 new

This is a wrapper for the glade constructor.

  $frame = MainFrame->new(lots of junk);

=cut

sub new {
  my $self = shift;
  my ($parent, $id, $title, $pos, $size, $style, $name ) = @_;
  $parent = undef              unless defined $parent;
  $id     = -1                 unless defined $id;
  $title  = ""                 unless defined $title;
  $pos    = wxDefaultPosition  unless defined $pos;
  $size   = (1 ?
    Wx::Size->new(800,600) :
    wxDefaultSize
    )                          unless defined $size;
  $name   = ""                 unless defined $name;

  # this is like SUPER but one step removed...
  $self = $self->__wx_glade_sub_new(
    $parent, $id, $title, $pos, $size, $style, $name
    );

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


sub __set_properties {
	my $self = shift;

# THIS IS AUTOGENERATED CODE: {
# begin wxGlade: MainFrame::__set_properties

	$self->SetTitle("dotReader");
	my $icon = Wx::Icon->new();
	$icon->CopyFromBitmap(Wx::Bitmap->new(dtRdr->data_dir."gui_default/icons/dotreader.ico", wxBITMAP_TYPE_ANY));
	$self->SetIcon($icon);
	$self->SetSize(Wx::Size->new(800, 600));
	$self->{frame_main_statusbar}->SetStatusWidths(-1,-1);
	
	my( @frame_main_statusbar_fields ) = (
		"",
		""
	);

	if( @frame_main_statusbar_fields ) {
		$self->{frame_main_statusbar}->SetStatusText($frame_main_statusbar_fields[$_], $_) 	
		for 0 .. $#frame_main_statusbar_fields ;
	}
	$self->{nv_title_bar}->SetFont(Wx::Font->new(12, wxDEFAULT, wxNORMAL, wxBOLD, 0, ""));
	$self->{nv_button_goto}->SetToolTipString("goto");
	$self->{nv_button_goto}->SetSize($self->{nv_button_goto}->GetBestSize());
	$self->{nv_button_edit}->SetToolTipString("edit");
	$self->{nv_button_edit}->SetSize($self->{nv_button_edit}->GetBestSize());
	$self->{nv_button_delete}->SetToolTipString("delete");
	$self->{nv_button_delete}->SetSize($self->{nv_button_delete}->GetBestSize());
	$self->{nv_button_close}->SetToolTipString("close");
	$self->{nv_button_close}->SetSize($self->{nv_button_close}->GetBestSize());

# end wxGlade
# THAT WAS AUTOGENERATED CODE }
} # end __set_properties

sub __do_layout {
	my $self = shift;

# THIS IS AUTOGENERATED CODE: {
# begin wxGlade: MainFrame::__do_layout

	$self->{sizer_1} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{note_viewer_sizer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{note_viewer_gridsizer} = Wx::FlexGridSizer->new(1, 5, 0, 0);
	$self->{note_viewer_gridsizer}->Add($self->{nv_title_bar}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{note_viewer_gridsizer}->Add($self->{nv_button_goto}, 0, wxADJUST_MINSIZE, 0);
	$self->{note_viewer_gridsizer}->Add($self->{nv_button_edit}, 0, wxADJUST_MINSIZE, 0);
	$self->{note_viewer_gridsizer}->Add($self->{nv_button_delete}, 0, wxADJUST_MINSIZE, 0);
	$self->{note_viewer_gridsizer}->Add($self->{nv_button_close}, 0, wxADJUST_MINSIZE, 0);
	$self->{note_viewer_gridsizer}->AddGrowableCol(0);
	$self->{note_viewer_sizer}->Add($self->{note_viewer_gridsizer}, 0, wxRIGHT|wxEXPAND|wxALIGN_RIGHT|wxADJUST_MINSIZE, 0);
	$self->{note_viewer_sizer}->Add($self->{nv_htmlwidget}, 1, wxEXPAND, 0);
	$self->{note_viewer_pane}->SetAutoLayout(1);
	$self->{note_viewer_pane}->SetSizer($self->{note_viewer_sizer});
	$self->{note_viewer_sizer}->Fit($self->{note_viewer_pane});
	$self->{note_viewer_sizer}->SetSizeHints($self->{note_viewer_pane});
	$self->{right_window}->SplitHorizontally($self->{bv_manager}, $self->{note_viewer_pane}, );
	$self->{window_1}->SplitVertically($self->{sidebar}, $self->{right_window}, 195);
	$self->{sizer_1}->Add($self->{window_1}, 1, wxEXPAND, 0);
	$self->SetAutoLayout(1);
	$self->SetSizer($self->{sizer_1});
	$self->Layout();
	$self->Centre();

# end wxGlade
# THAT WAS AUTOGENERATED CODE }
} # end __do_layout

=head2 __wx_glade_sub_new

This just hides the autogenerated code so I don't have to look at it.

  __wx_glade_sub_new(@standard_wx_args);

=cut

sub __wx_glade_sub_new {
  my $self = shift;
  my ($parent, $id, $title, $pos, $size, $style, $name ) = @_;

# THIS IS AUTOGENERATED CODE: {
# begin wxGlade: MainFrame::new

	$style = wxDEFAULT_FRAME_STYLE
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{window_1} = Wx::SplitterWindow->new($self, 501, wxDefaultPosition, wxDefaultSize, wxSP_3D|wxSP_BORDER);
	$self->{right_window} = Wx::SplitterWindow->new($self->{window_1}, -1, wxDefaultPosition, wxDefaultSize, wxSP_3D|wxSP_BORDER);
	$self->{note_viewer_pane} = dtRdr::GUI::Wx::NoteViewer->new($self->{right_window}, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{frame_main_statusbar} = $self->CreateStatusBar(2, wxST_SIZEGRIP);
	use dtRdr::GUI::Wx::Sidebar;
	$self->{sidebar} = dtRdr::GUI::Wx::Sidebar->new($self->{window_1}, -1);
	use dtRdr::GUI::Wx::BVManager;
	$self->{bv_manager} = dtRdr::GUI::Wx::BVManager->new($self->{right_window}, -1, wxDefaultPosition, wxDefaultSize);
	$self->{nv_title_bar} = Wx::StaticText->new($self->{note_viewer_pane}, -1, "Title goes here", wxDefaultPosition, wxDefaultSize, );
	$self->{nv_button_goto} = Wx::BitmapButton->new($self->{note_viewer_pane}, -1, Wx::Bitmap->new(dtRdr->data_dir."gui_default/icons/nv_button_goto.png", wxBITMAP_TYPE_ANY));
	$self->{nv_button_edit} = Wx::BitmapButton->new($self->{note_viewer_pane}, -1, Wx::Bitmap->new(dtRdr->data_dir."gui_default/icons/nv_button_edit.png", wxBITMAP_TYPE_ANY));
	$self->{nv_button_delete} = Wx::BitmapButton->new($self->{note_viewer_pane}, -1, Wx::Bitmap->new(dtRdr->data_dir."gui_default/icons/nv_button_delete.png", wxBITMAP_TYPE_ANY));
	$self->{nv_button_close} = Wx::BitmapButton->new($self->{note_viewer_pane}, -1, Wx::Bitmap->new(dtRdr->data_dir."gui_default/icons/nv_button_close.png", wxBITMAP_TYPE_ANY));
	use dtRdr::HTMLWidget;
	$self->{nv_htmlwidget} = dtRdr::HTMLWidget->new($self->{note_viewer_pane}, -1, wxDefaultPosition, wxDefaultSize);

	$self->__set_properties();
	$self->__do_layout();

# end wxGlade
# THAT WAS AUTOGENERATED CODE }

  return($self);
} # end subroutine __wx_glade_sub_new definition
########################################################################

# end of class MainFrame

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

# vim:ts=2:sw=2:et:sts=2:sta:nowrap