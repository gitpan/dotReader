package dtRdr::GUI::Wx::NoteEditor;
$VERSION = eval{require version}?version::qv($_):$_ for(0.0.1);

use strict;
use warnings;

use Wx qw(
  :everything
);

use base 'dtRdr::GUI::Wx::NoteEditorBase';

# THIS IS AUTOGENERATED CODE: {
# begin wxGlade: ::dependencies
# end wxGlade
# THAT WAS AUTOGENERATED CODE }

=head1 NAME

dtRdr::GUI::Wx::NoteEditor - autogenerated code

=head1 SYNOPSIS

This module is scheduled to get some nice concrete boots and a trip to
the lake.

=cut

sub new {
  my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
  $parent = undef              unless defined $parent;
  $id     = -1                 unless defined $id;
  $title  = ""                 unless defined $title;
  $pos    = wxDefaultPosition  unless defined $pos;
  $size   = (0
    ? Wx::Size->new(300,250)
    : wxDefaultSize
    )                          unless defined $size;
  $name   = ""                 unless defined $name;

  # this is like SUPER but one step removed...
  $self = $self->__wx_glade_sub_new(
    $parent, $id, $title, $pos, $size, $style, $name
    );
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



=head2 __wx_glade_sub_new

  $self = $self->__wx_glade_sub_new('blah blah blah');

=cut

sub __wx_glade_sub_new {
    my $self = shift;
  my ($parent, $id, $title, $pos, $size, $style, $name ) = @_;
# THIS IS AUTOGENERATED CODE: {
# begin wxGlade: NoteEditor::new

	$style = wxDEFAULT_FRAME_STYLE
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{label_title} = Wx::StaticText->new($self, -1, "Title", wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT);
	$self->{text_ctrl_title} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
	$self->{label_body} = Wx::StaticText->new($self, -1, "Body", wxDefaultPosition, wxDefaultSize, );
	$self->{text_ctrl_body} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER|wxTE_MULTILINE);
	$self->{button_cancel} = Wx::Button->new($self, -1, "Cancel");
	$self->{button_submit} = Wx::Button->new($self, -1, "Submit");

	$self->__set_properties();
	$self->__do_layout();

# end wxGlade
# THAT WAS AUTOGENERATED CODE }
    return($self);
} # end subroutine __wx_glade_sub_new definition
########################################################################

sub __set_properties {
	my $self = shift;

# THIS IS AUTOGENERATED CODE: {
# begin wxGlade: NoteEditor::__set_properties

	$self->SetTitle("Note Editor");
	my $icon = Wx::Icon->new();
	$icon->CopyFromBitmap(Wx::Bitmap->new(dtRdr->data_dir."gui_default/icons/kedit.png", wxBITMAP_TYPE_ANY));
	$self->SetIcon($icon);
	$self->SetSize(Wx::Size->new(320, 240));

# end wxGlade
# THAT WAS AUTOGENERATED CODE }
}

sub __do_layout {
	my $self = shift;

# THIS IS AUTOGENERATED CODE: {
# begin wxGlade: NoteEditor::__do_layout

	$self->{grid_sizer_2} = Wx::FlexGridSizer->new(3, 2, 2, 2);
	$self->{grid_sizer_3} = Wx::FlexGridSizer->new(1, 3, 0, 0);
	$self->{grid_sizer_2}->Add($self->{label_title}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{text_ctrl_title}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{label_body}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{text_ctrl_body}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add(20, 20, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_3}->Add(20, 20, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_3}->Add($self->{button_cancel}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_3}->Add($self->{button_submit}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_3}->AddGrowableCol(0);
	$self->{grid_sizer_2}->Add($self->{grid_sizer_3}, 1, wxEXPAND, 0);
	$self->SetAutoLayout(1);
	$self->SetSizer($self->{grid_sizer_2});
	$self->{grid_sizer_2}->AddGrowableRow(1);
	$self->{grid_sizer_2}->AddGrowableCol(1);
	$self->Layout();
	$self->Centre();

# end wxGlade
# THAT WAS AUTOGENERATED CODE }
}

# end of class NoteEditor

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
