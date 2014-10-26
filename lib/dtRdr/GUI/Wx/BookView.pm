package dtRdr::GUI::Wx::BookView;

use warnings;
use strict;
use Carp;

our $VERSION = '0.01';

use List::History;
use dtRdr::Range;
use dtRdr::Highlight;
use dtRdr::Note;
use dtRdr::Bookmark;

=head1 NAME

dtRdr::GUI::Wx::BookView - view of an open book

=head1 SYNOPSIS

This contains the history, widget, book, tree, ...

=cut

use Wx qw(
  wxID_OK
  wxOK
  wxCANCEL
);

use dtRdr::Accessor;
dtRdr::Accessor->ro(qw(
  manager
  book
  book_tree
  note_tree
  bookmark_tree
  highlight_tree
  htmlwidget
  history
));
dtRdr::Accessor->rw(qw(
  requested_toc
  current_toc
  current_url
  history_in_progress
));

use Method::Alias (
  hw      => 'htmlwidget',
);

use dtRdr::Logger;

=head1 Contructor

=head2 new

  my $bv = dtRdr::GUI::Wx::BookView->new($book);

=cut

sub new {
  my $package = shift;
  my ($book) = @_;
  my $class = ref($package) || $package;
  my $self = {
    book => $book
  };
  bless($self, $class);
  return($self);
} # end subroutine new definition
########################################################################

=head2 init

  $bv->init($bvm);

=cut

# TODO this should:
#   $self->make_hooks($bvm->parent);
#   $widget->set_view($self); # or something
#
#   $booktree->populate ...

sub init {
  my $self = shift;
  my ($bvm) = @_;

  $self->{manager} = $bvm;

  my %spec = (
    url      => 'string',
    scroll_y => 'integer',
  );
  $self->{history} = List::History->new(moment_spec => \%spec);

} # end subroutine init definition
########################################################################


=head2 set_widgets

  $bv->set_widgets(%args);

=cut

sub set_widgets {
  my $self = shift;
  my %args = @_;
  foreach my $key (keys(%args)) {
    $self->{$key} = $args{$key};
  }
} # end subroutine set_widgets definition
########################################################################

=head2 make_hooks

  $bv->make_hooks($frame);

=cut

sub make_hooks {
  my $self = shift;
  die "not done";
} # end subroutine make_hooks definition
########################################################################

=head1 URL Handling

=head2 load_url

This serves as both a dispatch point (for onclick handlers) and as an
external interface.  In order to properly use the history, you should
call this rather than the htmlwidget methods.

  $is_handled = $bv->load_url($url);

=cut

sub load_url {
  my $self = shift;
  my ($url, $killit) = @_;
  # TODO might need more options like scroll_y
  $killit ||= sub {};

  use URI;
  my $uri = URI->new($url);
  RL('#links')->debug("pondering $url");

  ######################################################################
  # anchor handling {{{
  my $anchor;
  if(defined($anchor = $uri->fragment) and
    $uri->path eq '/' . $self->current_toc->id
    ) {
    $killit->();
    RL('#links')->debug("local jump to $anchor");
    $self->hw->jump_to_anchor($anchor);
    return(1);
  }
  elsif(defined($anchor)) {
    # This case should usually just pass-through till later?

    0 and WARN("want $url ",
      join('|',
        map({"$_ => " . ($uri->$_ || '')} qw(scheme authority path))
      )
    );

  }
  # anchor handling }}}
  ######################################################################

  if(my $scheme = $uri->scheme) {
    if($scheme eq 'pkg') {
      RL('#links')->debug("this is an internal link");
      my $pkg = $uri->authority;
      my @urlpath = split(/\//, $uri->path);
      my $id = $urlpath[-1];
      RL('#links')->debug("id:$id pkg:$pkg");
      #$evt->{Cancel} = 1 ;
      # TODO check that $pkg is the current book
      $killit->();
      eval {
        $self->render_node_by_id($id);
      };
      # TODO $mainframe->error or something
      $@ and RL('#user')->error("follow link to '$id' failed");
      return(1);
    }
    elsif($scheme eq 'dr') {
      RL('#links')->debug("dr link: '$url'");
      $killit->();

      # make sure we know what we're supposed to do with it
      my $auth = $uri->authority;
      ($auth eq 'LOCAL') or croak("cannot handle '$url'");

      # hrmm, URI doesn't like dr://
      my @parts = split(/\/+/, $uri->path);
      shift(@parts); # drop leading null
      # maybe no biggie if there's too many
      (@parts == 1) or warn
        "scary path (@parts) '$url', probably broken...";
      my $resource = $parts[-1];
      my $ext;
      if($resource =~ s/(.+)\.([^.]+)/$1/) {
        defined($2) or die "oops $resource";
        $ext = $2;
      }
      else {
        die "confusing resource type:  '$resource'";
      }

      # now, decide what foo.bar means -- a note perhaps?
      if($ext eq 'drnt') {
        $self->show_note($resource);
      }
      elsif($ext eq 'drbm') {
        # TODO bookmark links do nothing
        return;
      }
      elsif($ext eq 'copy') {
        $self->show_literal_section($resource);
        return;
      }
      else {
        RL('#user')->error("unknown type '$ext' in  '$url'");
      }

      return(1);
    }
    elsif($scheme eq 'ftp') {
      RL('#links')->debug("dropping FTP links");
      $killit->();
      return(1);
    }
    elsif($scheme eq 'mailto') {
      RL('#links')->debug("dropping mailto links");
      $killit->();
      return(1);
    }
  }
  #else{
  #  warn "attempting to get file from pkg";
  #  if ($book->get_filedata($url)){
  #    return $book->get_filedata($url);
  #  }
  #}

  my $hw = $self->hw;

  # now we're leaving the book for an external page
  RL('#history')->debug("try to add history for web page");
  $self->history_add;
  $self->set_current_url($url);

  unless($hw->load_in_progress) { # TODO a better way?
    RL('#links')->debug("dispatch to browser\n");
    $hw->load_url($url);
  }
  RL('#links')->debug("returns");
  return(0);
} # end subroutine load_url definition
########################################################################

=head2 refresh

Only if you're reading a book (for now.)

  $self->refresh;

=cut

sub refresh {
  my $self = shift;

  # NOTE we shouldn't have to muck with "by_id()" here
  $self->hw->reset_wrap(sub {
    $self->render_node($self->current_toc);
  });
} # end subroutine refresh definition
########################################################################

=head2 is_visible

Returns true if the TOC node is visible.

  $bv->is_visible($node);

=cut

sub is_visible {
  my $self = shift;
  my ($node) = @_;
  my $toc = $self->current_toc;
  my @to_check = ($toc, $self->book->descendant_nodes($toc));
  @to_check = grep({$_ eq $node} @to_check);
  (@to_check > 1) and die 'bad book (',
    scalar(@to_check), ' nodes: ', join('|', @to_check), ')';
  return(scalar(@to_check));
} # end subroutine is_visible definition
########################################################################

=head2 jump_to

Jump to an object (currently this must be an annotation, but all it
needs to be is something which responds to id(), book(), and node()
methods, where the value of id maps to an anchor name on the resultant
page.)

  $bv->jump_to($annotation);

=cut

sub jump_to {
  my $self = shift;
  my ($obj) = @_;

  $obj->can('book') or die;
  unless($self->book eq $obj->book) {
    croak("cannot jump to other books");
  }
  $obj->can('node') or die;
  my $node = $obj->node;
  # first make sure we can see it
  unless($self->is_visible($node)) {
    $self->render_node_by_id($node->id);
  }
  # then just fabricate an anchor and scroll there
  $self->hw->jump_to_anchor($obj->id);

} # end subroutine jump_to definition
########################################################################

=head2 set_requested_toc

  $self->set_requested_toc($reqtoc);

=cut

sub set_requested_toc {
  my $self = shift;
  my ($toc) = @_;
  # TODO ensure that the BookTree has this item selected!
  $self->SUPER::set_requested_toc($toc);
} # end subroutine set_requested_toc definition
########################################################################

=head1 utilities

=head2 selection_as_range

  my $range = $bv->selection_as_range;

=cut

sub selection_as_range {
  my $self = shift;

  my $book = $self->book();
  my $current_toc = $self->current_toc();
  my $html_widget = $self->htmlwidget();

  my ($lstr, $str, $rstr) = $html_widget->get_selection_context(40);
  length($str) or return;
  $_ =~ s/\s+/ /g for($lstr, $str, $rstr);
  L->debug("$lstr|  |$str|  |$rstr");
  my $range = $book->locate_string($current_toc, $str, $lstr, $rstr);
  $range or L->warn('something wrong with selection');
  return($range);
} # end subroutine selection_as_range definition
########################################################################

=head1 Annotations

=head2 highlight_at_selection

  $bv->highlight_at_selection;

=cut

sub highlight_at_selection {
  my $self = shift;
  my ($range) = @_; # only applicable in testing

  $range ||= $self->selection_as_range;
  $range or return;
  my $highlight = dtRdr::Highlight->claim($range) or
    die 'lost the range';
  $highlight->set_title($highlight->get_selected_string);
  my $book = $self->book;
  # put it in the book
  $book->add_highlight($highlight);
  # and the highlight tree (does that really need to have the book?)
  $self->highlight_tree->add_item($highlight);
  $self->refresh;
  return($highlight);
} # end subroutine highlight_at_selection definition
########################################################################

=head1 Notes

=head2 note_at_selection

Create a note and launch the note editor.

  $bv->note_at_selection;

=cut

sub note_at_selection {
  my $self = shift;

  my $range = $self->selection_as_range;
  my $note;
  if($range) {
    $note = dtRdr::Note->claim($range) or die 'lost the range';
    $note->set_title($note->get_selected_string);
  }
  else {
    # TODO do we have to ask if you mean a child!?
    $note = dtRdr::Note->create(
      node => $self->current_toc,
      range => [undef,undef],
    );
    $note->set_title('');
  }

  use dtRdr::GUI::Wx::NoteEditor;
  my $editor = dtRdr::GUI::Wx::NoteEditor->new();

  # we could do this as ShowModal, but that seems a bit too strict
  # since it's going to ~thread, we need to pass it subrefs

  # but add the note and render it -- user can then background this
  my $book = $self->book;
  $book->add_note($note);
  # and render that
  $self->refresh;

  $self->note_tree->add_item($note);

  my $saver = sub {
    $note->set_title($editor->text_ctrl_title->GetValue);
    $note->set_content($editor->text_ctrl_body->GetValue);
    $book->do_serialize('update', $note);
    $self->manager->note_viewer->note_changed($note); # XXX icky
    $self->note_tree->item_changed($note);
  };
  $editor->set_saver($saver);

  # TODO
  #   Q: what if they decide to come back and edit it again while that
  #     editor is still open?
  #   A: have a list of editor objects and just do $editor->Raise
  my $reverter = sub {
    $self->delete_note($note);
  };
  $editor->set_reverter($reverter);

  # TODO set_autosaver

  # defer the show until here because it messes with focus otherwise
  $editor->Show(1);
} # end subroutine note_at_selection definition
########################################################################

=head2 bookmark_at_selection

  $bv->bookmark_at_selection;

=cut

sub bookmark_at_selection {
  my $self = shift;

  my $range = $self->selection_as_range;
  my $bm;
  if($range) {
    $bm = dtRdr::Bookmark->claim($range) or die 'lost the range';
    $bm->set_title($bm->get_selected_string);
  }
  else {
    # TODO do we have to ask if you mean a child!?
    my $node = $self->current_toc;
    $bm = dtRdr::Bookmark->create(
      node => $node,
      range => [undef,undef],
    );
    $bm->set_title($node->get_title);
  }
  my $ask = Wx::TextEntryDialog->new(
    $self->manager,
    '',
    'Title for new bookmark',
    $bm->get_title,
    wxOK|wxCANCEL
  );
  if($ask->ShowModal != wxID_OK) {
    return;
  }
  $bm->set_title($ask->GetValue);
  my $book = $self->book;
  $book->add_bookmark($bm);
  $self->bookmark_tree->add_item($bm);
  $self->refresh;
} # end subroutine bookmark_at_selection definition
########################################################################

=head2 show_note

  $self->show_note($id);

=cut

sub show_note {
  my $self = shift;
  my ($note_id) = @_;

  # TODO enable the manager->anno_io to lookup by id?

  if(my $note = $self->book->find_note($note_id)) {
    $self->manager->note_viewer->show_note($note);
  }
  else {
    RL('#user')->error("nothing found for $note_id");
  }
} # end subroutine show_note definition
########################################################################

=head2 edit_note

Edit an existing note.

  $bv->edit_note($note);

=cut

sub edit_note {
  my $self = shift;
  my ($note) = @_;
  eval{$note->isa('dtRdr::Note')} or
    croak("'$note' is not a dtRdr::Note");

  # check whether we have this book
  unless($self->book eq $note->book) {
    # eek
    RL('#gui')->error('cannot edit notes for non-open books yet');
    return();
  }

  use dtRdr::GUI::Wx::NoteEditor;
  if(0) {
  # TODO check for existing editor and raise if so
    WARN("edit_note() not done yet");
  }
  else {
    # make a new one with a proper revert
    my $editor = dtRdr::GUI::Wx::NoteEditor->new();
    $editor->set_fields(
      title => $note->title,
      body  => $note->content,
    );

    my $book = $self->book;
    my $saver = sub {
      $note->set_title($editor->text_ctrl_title->GetValue);
      $note->set_content($editor->text_ctrl_body->GetValue);
      $book->do_serialize('update', $note);
      $self->manager->note_viewer->note_changed($note); # XXX icky
      $self->note_tree->item_changed($note);
    };
    $editor->set_saver($saver);
    # need to have a serialized note
    # (though this only matters if we have autosave enabled)
    my $snapshot = $note->clone;
    my $reverter = sub {
      WARN("revert not working yet");
      # we have to write into the existing object
      %$note = %$snapshot;
      $book->do_serialize('update', $note);
      $self->manager->note_viewer->note_changed($note); # XXX icky
      $self->note_tree->item_changed($note);
    };
    $editor->set_reverter($reverter);
    # TODO autosaver
    # defer the show until here because it messes with focus otherwise
    $editor->Show(1);
  }
} # end subroutine edit_note definition
########################################################################

=head2 _delete_anno

Actions common to all deletions.

  $self->_delete_anno($anno);

=cut

sub _delete_anno {
  my $self = shift;
  my ($anno) = @_;

  # check whether we have this book
  unless($self->book == $anno->book) {
    # eek
    RL('#gui')->error('cannot edit notes for non-open books yet');
    return();
  }
  my $type = {
    'dtRdr::Note'      => 'note',
    'dtRdr::Bookmark'  => 'bookmark',
    'dtRdr::Highlight' => 'highlight',
  }->{ref($anno)};
  $type or die;
  my $book_method = 'delete_' . $type;
  $self->book->$book_method($anno);

  my $tree = $type . '_tree';

  $self->$tree->delete_item($anno);
  # can't click with deleted anno => rerender iff we're still there.
  $self->refresh if($self->is_visible($anno->node));
  return(1);
} # end subroutine _delete_anno definition
########################################################################

=head2 delete_note

Definitive place to delete a note WRT to GUI.

  $bv->delete_note($note);

=cut

sub delete_note {
  my $self = shift;
  my ($note) = @_;
  eval{$note->isa('dtRdr::Note')} or
    croak("'$note' is not a dtRdr::Note");


  $self->_delete_anno($note) or return;
  # let the note viewer know
  my $nv = $self->manager->note_viewer;
  $nv->no_note if($note eq ($nv->note || ''));

} # end subroutine delete_note definition
########################################################################

=head2 delete_bookmark

  $bv->delete_bookmark($bm);

=cut

sub delete_bookmark {
  my $self = shift;
  my ($bookmark) = @_;
  eval{$bookmark->isa('dtRdr::Bookmark')} or
    croak("'$bookmark' is not a bookmark");
  $self->_delete_anno($bookmark) or return;
} # end subroutine delete_bookmark definition
########################################################################

=head2 delete_highlight

  $bv->delete_highlight($hl);

=cut

sub delete_highlight {
  my $self = shift;
  my ($highlight) = @_;
  eval{$highlight->isa('dtRdr::Highlight')} or
    croak("'$highlight' is not a highlight");
  $self->_delete_anno($highlight) or return;
} # end subroutine delete_highlight definition
########################################################################


=head1 Book Handling

=head2 render_node

Probably a private method -- else you break the history.

  $bv->render_node($toc);

=cut

sub render_node {
  my $self = shift;
  my ($toc) = @_;
  eval { $toc->isa('dtRdr::TOC') } or croak("not a toc");
  $self->set_current_toc($toc);

  # set state

  # trying to prevent input from impatient users -- not working
  # TODO do the load in a worker?
  #      use a progress dialog? (only on large nodes?)
  $self->manager->main_frame->Enable(0);
  my $html = $self->book->get_content($toc);
  $self->htmlwidget->render_HTML($html, $self->book);
  $self->manager->main_frame->Enable(1);
  $self->htmlwidget->SetFocus;
} # end subroutine render_node definition
########################################################################

=head2 render_node_by_id

Because some book formats allow toc items to point to other nodes,
book->find_toc is called to determine which node to render.  This method
is preferred over C<render_node()> because it gives the book a chance to
switcharoo the rendered node in the event of a reference/goto.

Sets C<requested_toc> to the node given by $id, but sets C<current_toc>
to the found node and renders that.

  $bv->render_node_by_id($id);

=cut

sub render_node_by_id {
  my $self = shift;
  my ($id) = @_;
  my $book = $self->book;

  my $root = $book->toc;
  my $reqtoc = $root->get_by_id($id);
  $self->book_tree->select_item($id);
  $self->set_requested_toc($reqtoc);

  my $toc = $book->find_toc($id);
  $toc or croak("could not find toc $id");

  $self->history_add;

  # create a url for this node and remember it
  my $url = URI->new('pkg://'.$book->id.'/'.$toc->id)->as_string;
  $self->set_current_url($url);


  $self->render_node($toc);
} # end subroutine render_node_by_id definition
########################################################################

=head2 show_literal_section

  $self->show_literal_section($id);

=cut

sub show_literal_section {
  my $self = shift;
  my ($id) = @_;

  my $book = $self->book;
  my $node = $book->find_toc($id);
  my $content = $book->get_copy_content($node);

  use dtRdr::GUI::Wx::TextViewer;
  my $viewer = dtRdr::GUI::Wx::TextViewer->new;
  $viewer->SetTitle($node->title . ' - Text View');
  $viewer->set_content($content);
  $viewer->Show(1);
  return($viewer);
} # end subroutine show_literal_section definition
########################################################################

=head1 Up and Down

Renders the next or previous "page" of the book.  This should be
analogous to turning pages in a physical book.

=over

=item notes

PageDown shows the next linear piece of content.

PageUp is the opposite of PageDown.

Ctrl+PageUp/down does a tree jump, staying on the same depth if possible.

Home/End do scrolling.

=back

=head2 render_next_page

Moves to the next page in the book.  Within a node, "page" is a relative
term equal to one visible screen of content.  At the end of the node,
the "next node" will be loaded.

  $bv->render_next_page

=cut

sub render_next_page {
  my $self = shift;

  return if $self->htmlwidget->scroll_page_down;
  # couldn't scroll down, get next page

  my $toc = ($self->requested_toc);
  if (my $dest = $self->book->next_node($toc)) {
    $self->render_node_by_id($dest->id);
  }
  return;

} # end subroutine render_next_page definition
########################################################################

=head2 render_prev_page

Page-up in the widget.  If at the top of the screen, load the (linearly)
previous node and scroll to the bottom.

  $bv->render_prev_page;

=cut

sub render_prev_page {
  my $self = shift;

  return if $self->htmlwidget->scroll_page_up;
  # couldn't scroll up, get next page
  my $toc = ($self->requested_toc);
  my $dest = $self->book->prev_node($toc);
  if($dest) {
    $self->render_node_by_id($dest->id);
  }
  return;
} # end subroutine render_prev_page definition
########################################################################


=head1 State Switching

=head2 freeze

  $bv->freeze;

=cut

sub freeze {
  my $self = shift;
  die "not done";
  # NOTE just rebless and put thaw in the BookView::Frozen package
} # end subroutine freeze definition
########################################################################

=head2 thaw

  $bv->thaw;

=cut

sub thaw {
  my $self = shift;
  die "not done";
} # end subroutine thaw definition
########################################################################

=head1 History Methods

These take no arguments.  The view has everything it needs to handle the
moments.

=head2 history_back

  $bv->history_back;

=cut

sub history_back {
  my $self = shift;
  my $hist = $self->history;
  $hist->has_prev or croak("no previous history");

  $self->remember;

  RL('#history')->debug("history_back");
  my $moment = $hist->back;
  my $bvm = $self->manager;
  $bvm->disable('navigation_history_back') unless($hist->has_prev);
  $bvm->enable('navigation_history_next');

  $self->_history_action(sub { $self->load_url($moment->url); });
  $self->hw->set_scroll_pos($moment->scroll_y);
} # end subroutine history_back definition
########################################################################

=head2 history_next

  $bv->history_next;

=cut

sub history_next {
  my $self = shift;
  my $hist = $self->history;
  $hist->has_next or croak("no forward history");

  $self->remember; # for scroll pos

  RL('#history')->debug("history_next");
  my $moment = $hist->foreward;
  my $bvm = $self->manager;
  $bvm->disable('navigation_history_next') unless($hist->has_next);
  $bvm->enable('navigation_history_back');

  $self->_history_action(sub { $self->load_url($moment->url); });
  $self->hw->set_scroll_pos($moment->scroll_y);
} # end subroutine history_next definition
########################################################################

=head2 _history_action

  $self->_history_action($subref);

=cut

sub _history_action {
  my $self = shift;
  my ($subref) = @_;

  $self->set_history_in_progress(1);
  $subref->();
  $self->set_history_in_progress(0);
} # end subroutine _history_action definition
########################################################################


=head2 remember

  $bv->remember;

=cut

sub remember {
  my $self = shift;
  my $hist = $self->history;
  if($hist->has_current) { # just mod the scroll position
    $hist->get_current->set_scroll_y($self->hw->get_scroll_pos);
  }
  else {
    RL('#history')->debug("\n\nrememberation\n\n");
    $hist->remember(
      url => $self->current_url,
      scroll_y => $self->hw->get_scroll_pos
    );
  }
} # end subroutine remember definition
########################################################################

=head2 history_add

Add the current url and position to the history (call this before moving
onward.)

  $self->history_add;

=cut

sub history_add {
  my $self = shift;
  $self->history_in_progress and return;

  if(defined(my $old_url = $self->current_url)) {
  RL('#history')->debug("\nadd history\n\n");
    # add the page we are leaving
    $self->history->add(
      url => $old_url,
      scroll_y => $self->hw->get_scroll_pos
    );
  }
  $self->manager->enable('navigation_history_back')
    if($self->history->has_prev);
} # end subroutine history_add definition
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
