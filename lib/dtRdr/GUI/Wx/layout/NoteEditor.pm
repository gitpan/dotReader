package dtRdr::GUI::Wx::layout::NoteEditor;
$VERSION = eval{require version}?version::qv($_):$_ for(0.0.1);

use strict;
use warnings;

use Wx ();
use WxPerl::ShortCuts;

use base 'Wx::Frame';

use dtRdr::GUI::Wx::Utils;

=head1 NAME

dtRdr::GUI::Wx::NoteEditor - was once autogenerated code

=head1 SYNOPSIS


=cut

=head2 new

Sets some properties, creates child widgets, etc. and calls init().

=cut

sub new {
  my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
  $parent = undef              unless defined $parent;
  $id     = -1                 unless defined $id;
  $title  = ""                 unless defined $title;
  $pos    = DefP  unless defined $pos;
  $size   = (0
    ? Wx::Size->new(300,250)
    : DefS
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

	$style = WX"DEFAULT_FRAME_STYLE" unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{label_title} = Wx::StaticText->new($self, -1, "Title", DefPS, WX"ALIGN_RIGHT");
	$self->{text_ctrl_title} = Wx::TextCtrl->new($self, -1, "", DefPS, TE"PROCESS_ENTER");
	$self->{label_body} = Wx::StaticText->new($self, -1, "Body", DefPS, );
	$self->{text_ctrl_body} = Wx::TextCtrl->new($self, -1, "", DefPS, TE"PROCESS_ENTER|MULTILINE");
  $self->{checkbox_public} = Wx::CheckBox->new($self, -1, "Public", DefPS);
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
	$icon->CopyFromBitmap(
    dtRdr::GUI::Wx::Utils->Bitmap('kedit')
  );
	$self->SetIcon($icon);
	$self->SetSize(Wx::Size->new(320, 240));

# end wxGlade
# THAT WAS AUTOGENERATED CODE }
}

sub __do_layout {
	my $self = shift;

	my $gs2 = $self->{grid_sizer_2} = Wx::FlexGridSizer->new(4, 2, 2, 2);
	$gs2->Add($self->{label_title}, 0, Ams, 0);
	$gs2->Add($self->{text_ctrl_title}, 0, Exp|Ams, 0);
	$gs2->Add($self->{label_body}, 0, Ams, 0);
	$gs2->Add($self->{text_ctrl_body}, 0, Exp|Ams, 0);
	$gs2->Add(20, 20, 0, Exp|Ams, 0);
  $gs2->Add($self->{checkbox_public}, 0, Ams, 0);
	$gs2->Add(20, 20, 0, Exp|Ams, 0);
	my $gs3 = $self->{grid_sizer_3} = Wx::FlexGridSizer->new(1, 3, 0, 0);
    $gs3->Add(20, 20, 0, Exp|Ams, 0);
    $gs3->Add($self->{button_cancel}, 0, Ams, 0);
    $gs3->Add($self->{button_submit}, 0, Ams, 0);
    $gs3->AddGrowableCol(0);
	$gs2->Add($self->{grid_sizer_3}, 1, Exp, 0);

	$self->SetAutoLayout(1);
	$self->SetSizer($gs2);

	$gs2->AddGrowableRow(1);
	$gs2->AddGrowableCol(1);

	$self->Layout();
	$self->Centre();

}

# end of class NoteEditor

=head1 AUTHOR

I blame wxglade.  We're working on cleaning up though.

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