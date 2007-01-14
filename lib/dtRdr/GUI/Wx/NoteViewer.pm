package dtRdr::GUI::Wx::NoteViewer;
$VERSION = eval{require version}?version::qv($_):$_ for(0.10.1);

use warnings;
use strict;
use Carp;


use dtRdr::Note;
use dtRdr::Logger;

use Wx;
use base 'Wx::Panel';
# all the glade setup is still in MainFrame.pm
use Wx::Event qw(
  EVT_BUTTON
  EVT_SPLITTER_SASH_POS_CHANGED
  EVT_SPLITTER_SASH_POS_CHANGING
  EVT_SPLITTER_DOUBLECLICKED
);

use dtRdr::Accessor;
dtRdr::Accessor->ro qw(
  frame
  bv_manager
  htmlwidget
  window
  state
  title_bar
  bt_goto
  bt_edit
  bt_delete
  bt_close
);
dtRdr::Accessor->rw qw(
  notebar_changing
);
my $set_note = dtRdr::Accessor->ro_w('note');

=head1 NAME

dtRdr::GUI::Wx::NoteViewer - a special Wx::Panel

=head1 SYNOPSIS

=cut


=head2 init

  $nv->init($frame);

=cut

sub init {
  my $self = shift;
  my ($frame) = @_;

  { # copy-in some frame stuff
    $self->{frame} = $frame;
    $self->{bv_manager} = $frame->bv_manager;
    $self->{htmlwidget} = $frame->nv_htmlwidget;
    $self->{title_bar} = $frame->nv_title_bar;
    $self->{window} = $frame->right_window;
    $self->{state} = $frame->state;
    for(qw(
      goto
      edit
      delete
      close
      )) {
      my $frame_attribute = 'nv_button_' . $_;
      $self->{'bt_' . $_} = $frame->$frame_attribute;
    }
  }

  $self->htmlwidget->init($self);

  $self->SetMinSize(Wx::Size->new(-1, 0));

  { # connect the buttons
    my @button_map = (
      ['goto'   => 'goto_note'],
      ['edit'   => 'edit_note'],
      ['delete' => 'delete_note'],
      ['close'  =>
        sub { $self->notebar_toggle if($self->state->notebar_open); }
      ],
    );
    foreach my $row (@button_map) {
      my ($action, $sub) = @$row;
      $sub = eval("sub {\$self->$sub}") unless(ref($sub) eq 'CODE');
      my $bt_name = 'bt_' . $action;
      EVT_BUTTON($self, $self->$bt_name, sub {
        WARN("$action button");
        $sub->();
      });
    }
  } # end buttons

  EVT_SPLITTER_SASH_POS_CHANGING($self->window, $self->window,
    sub { $self->set_notebar_changing(1); $_[1]->Skip }
  );
  EVT_SPLITTER_SASH_POS_CHANGED($self->window, $self->window,
    sub { $self->notebar_changed($_[1]) }
  );
  EVT_SPLITTER_DOUBLECLICKED($self->window, $self->window,
    sub { $self->notebar_toggle() }
  );

} # end subroutine init definition
########################################################################

=head2 setup

  $nv->setup;

=cut

sub setup {
  my $self = shift;

  $self->no_note;

  if(0) {
    my $greeting =
      qq(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">) .
      "<html><body>no note</body></html>" .
      '';
    $self->htmlwidget->SetPage($greeting);
  }

  { # set the size
    my $win = $self->window;
    my ($x, $y) = $win->GetSizeWH;
    0 and WARN("window size $x, $y");

    # might Hide if the button slivers are annoying, but then we'll have
    # to manually show it
    #$self->Show(0);

    $win->SetSashPosition($y);
    # NOTE a bug on the widget?
  }

} # end subroutine setup definition
########################################################################

=head2 _enable_buttons

  $self->_enable_buttons;

=cut

sub _enable_buttons {
  my $self = shift;
  my ($bool) = @_;
  $bool = 1 unless(@_);
  defined($bool) or croak("invalid");

  foreach my $name (qw(
    goto
    edit
    delete
  )) {
    my $attribute = 'bt_' . $name;
    $self->$attribute->Enable($bool);
  }
} # end subroutine _enable_buttons definition
########################################################################

=head2 _disable_buttons

  $self->_disable_buttons;

=cut

sub _disable_buttons {
  my $self = shift;
  $self->_enable_buttons(0);
} # end subroutine _disable_buttons definition
########################################################################

=head2 notebar_changed

  $self->notebar_changed($event);

=cut

sub notebar_changed {
  my $self = shift;
  my ($event) = @_;

  RL('#notebar')->debug("'notebar_changed' fired");

  # this fires on a resize -- really bad, so we'll just track and skip
  $self->notebar_changing or return;
  $self->set_notebar_changing(0);

  # TODO there's one more case here where the window gets shrunk such
  # that our size is forced to be reduced.  When it is shrunk or
  # expanded (ala F7) this event fires once when it is done (~because
  # we're on the bottom here and gravity says so.)  At the moment, we're
  # not remembering the position that results from shrinkage (which is
  # good) but if the user re-enlarges the window and then fires the
  # toggle, it will change from the forced size to the remembered size,
  # which could be unsettling.  We should probably see if we have enough
  # room to reasonably expand back to our remembered size and then do
  # it.

  my $state = $self->state;
  # ok, this only fires on manual drags and not SetSashPosition() ?
  my $new_pos = $event->GetSashPosition;
  my $height = ($self->window->GetSizeWH)[1];
  my $nb_size = $height - $new_pos;
  RL('#notebar')->debug("pos changed to $new_pos ($nb_size)");

  if($nb_size < 60) {
    # meh, call it a draggy-toggle and DWIM
    if($state->notebar_open) { # you meant close, right?
      $state->set_notebar_open(0);
      $self->window->SetSashPosition($height);
    }
    else { # magic open
      # (un?)fortunately, this means the doubleclick is not needed from
      # the closed position.  Is that inconsistent?
      $state->set_notebar_open(1);
      $self->window->SetSashPosition($height - $state->notebar_position);
    }
  }
  else {
    # remember the new position (from the bottom)
    $state->set_notebar_position($nb_size);
    $state->set_notebar_open(1); # just in case
  }
} # end subroutine notebar_changed definition
########################################################################

=head2 notebar_toggle

  $self->notebar_toggle($event);

=cut

sub notebar_toggle {
  my $self = shift;
  my ($event) = @_;
  my $state = $self->state;
  my $pos = $self->window->GetSashPosition();
  my $height = ($self->window->GetSizeWH)[1];

  # TODO focus whichever tab is on top
  RL('#notebar')->debug("window toggle: $pos");
  # NOTE mac gets silly about this if SashPosition is less than 3
  my $open = $state->notebar_open;
  $self->window->SetSashPosition(
    $height - ($open ? 0 : $state->notebar_position)
  );
  $state->set_notebar_open(! $open);
} # end subroutine notebar_toggle definition
########################################################################


=head2 be_open

  $nv->be_open;

=cut

sub be_open {
  my $self = shift;
  $self->notebar_toggle unless($self->state->notebar_open);
} # end subroutine be_open definition
########################################################################

=head2 be_closed

  $nv->be_closed;

=cut

sub be_closed {
  my $self = shift;
  $self->notebar_toggle if($self->state->notebar_open);
} # end subroutine be_closed definition
########################################################################

=head1 Note Manipulation

The viewer has a concept of a "current" note, which is updated by the
BVManager and the C<show_note()> method.

=head2 no_note

Quit showing whatever note you were showing for whatever reason?

  $nv->no_note;

=cut

sub no_note {
  my $self = shift;
  # disable the control buttons
  $self->_disable_buttons;
  $self->title_bar->SetLabel('- no note -');
  $self->htmlwidget->SetPage('');
  $self->$set_note(undef);
  # TODO anything else?
  $self->be_closed;
} # end subroutine no_note definition
########################################################################

=head2 note_changed

Tell the viewer that the note changed.

  $nv->note_changed($note);

=cut

sub note_changed {
  my $self = shift;
  my ($note) = @_;

  return unless(
    $note and
    $self->note and
    ref($note)
    and ($note eq $self->note)
  );
  $self->show_note($note);
} # end subroutine note_changed definition
########################################################################

=head2 goto_note

  $self->goto_note;

=cut

sub goto_note {
  my $self = shift;
  $self->bv_manager->book_view->jump_to($self->note);
} # end subroutine goto_note definition
########################################################################

=head2 edit_note

  $self->edit_note;

=cut

sub edit_note {
  my $self = shift;
  $self->bv_manager->book_view->edit_note($self->note);
} # end subroutine edit_note definition
########################################################################

=head2 delete_note

  $self->delete_note;

=cut

sub delete_note {
  my $self = shift;
  # should just bv_manager->**_note() ?
  $self->bv_manager->book_view->delete_note($self->note);
  $self->no_note;
} # end subroutine delete_note definition
########################################################################

=head2 show_note

  $nv->show_note($note_object);

=cut

sub show_note {
  my $self = shift;
  my ($note) = @_;

  $self->_enable_buttons;

  # TODO to get the "edit this note" thing working, we should remember
  # the ID or something, but tying the view to the editor is bad --
  # needs to happen at bookview

  $self->be_open;
  my $title = $note->title;
  $title = '--' unless defined($title);
  my $content = $note->content;
  $self->title_bar->SetLabel($title);
  $self->$set_note($note);

  # TODO something about this css and html wrapping sillyness
  my $css = <<'CSS';
h1.title {
  color: #FF0000;
  font-size: 15px;
}
body {
	color: #000000;
	font-size: 12px;
	font-family: Geneva, Arial, Helvetica;
	background-color: white;
	margin-top: 0px;
	margin-left: 0px;
}
CSS

  $content =
    '<html><head>' .
    '<style>' . $css . '</style>' .
    '</head><body>' .
    #'<h1 class="title">' . $title . '</h1>' .
    '<p>' .
    (defined($content) ? $content : 'undef, sorry... hi mom!') .
    '</p></body></html>';

  $self->htmlwidget->SetPage($content);
} # end subroutine show_note definition
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
