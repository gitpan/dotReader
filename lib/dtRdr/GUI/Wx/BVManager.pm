package dtRdr::GUI::Wx::BVManager;

use warnings;
use strict;

our $VERSION = '0.01';

use dtRdr;
use dtRdr::Book;
use dtRdr::HTMLWidget;
use dtRdr::GUI::Wx::BookView;
use dtRdr::Annotation::IO;

use Wx (
  # ':everything',
  qw(
  wxHORIZONTAL
  wxVERTICAL
  wxEXPAND
  wxHW_NO_SELECTION
  wxDefaultSize
  wxDefaultPosition
  ));

use base 'Wx::Panel';

use dtRdr::Accessor;
dtRdr::Accessor->ro(qw(
    main_frame
    book_view
    sidebar
    htmlwidget
    anno_io
    note_viewer
));

use dtRdr::Logger;

=head1 NAME

dtRdr::GUI::Wx::BVManager - a container of sorts

=head1 SYNOPSIS

=head1 Inheritance

  Wx::Panel

=cut

=head1 Constructor

=head2 new

Creates a frame.

  $bv = dtRdr::GUI::Wx::BVManager->new($parent, @blahblahblah);

=cut

sub new {
  my $class = shift;
  my ($parent, @args) = @_;

  my $self = $class->SUPER::new($parent, @args);
  bless($self, $class);
  return($self);
} # end subroutine new definition
########################################################################

=head1 Setup

=head2 init

  $bvm->init($frame);

=cut

sub init {
  my $self = shift;
  my ($frame) = @_;

  $self->{main_frame} = $frame;
  $self->{sidebar} = $frame->sidebar;
  $self->{note_viewer} = $frame->note_viewer;

  my $widget = dtRdr::HTMLWidget->new([$self, -1]);
  $self->{htmlwidget}   = $widget;
  $widget->init($self);
  $self->show_welcome;
  if($widget->can('meddle')) {$widget->meddle();}

  if(0) {
    warn "\n\n";
    warn "mainframe is ", $self->GetParent->GetParent, "\n";
    warn "event handler: ", $widget->GetEventHandler, "\n";
    warn "event handler: ", $self->GetEventHandler, "\n\n --";
  }

  # we're a pane, so we make a sizer and set it on ourself
  my $sizer = $self->{sizer} = Wx::BoxSizer->new(
    wxHORIZONTAL
    #wxVERTICAL
    );
  $sizer->Add($widget, 1, wxEXPAND, 0);
  $self->SetAutoLayout(1);
  $self->SetSizer($sizer);
  $sizer->SetSizeHints($self);

  # might need to enable this if you want to be able to flip to a
  # full-screen noteviewer
  #$self->SetMinSize(Wx::Size->new(-1, 0));

  { # setup the core_link callback
    use File::Spec;
    use English '-no_match_vars';
    my $icon_dir = File::Spec->rel2abs(dtRdr->data_dir);
    # de-billify path so URI doesn't get silly
    $icon_dir =~ s#\\#/#g if($OSNAME eq 'MSWin32');

    dtRdr::Book->callbacks->set_core_link(sub {
      use URI;
      my ($file) = @_;
      return( URI->new(
        'file://' . $icon_dir . '/gui_default/icons/' . $file
        )->as_string
      );
    });
  }
  { # setup the img_src_rewrite callback
    if($widget->can('img_src_rewrite_sub')) {
      dtRdr::Book->callbacks->set_img_src_rewrite(
        $widget->img_src_rewrite_sub
      );
    }
  }

  # get ourselves an annotation IO object
  my $anno_io = $self->{anno_io} =
    dtRdr::Annotation::IO->new(uri => dtRdr->user_dir . 'annotations/');
} # end subroutine init definition
########################################################################


=head2 show_welcome

  $bvm->show_welcome;

=cut

sub show_welcome {
  my $self = shift;

  my $greeting = "this is " . ref($self->htmlwidget) . "<br>";
  L->info("setting greeting");

  if(0) { # playing with anchors
    $greeting .= qq(<p><a name="top">hi</a>) .
      qq( <a href="http://osoft.com/">osoft.com</a><br>) .
      qq( <a href="http://osoft.com/foo#bar">osoft.com/foo#bar</a><br>) .
      qq( <a href="http://osoft.com/foo.html#bar">osoft.com/foo.html#bar</a><br>) .
      qq( <a href="http://osoft.com/foo.html#bar">osoft.com/index.php#bar</a><br>) .
      qq( <a href="#foo">go to foo</a>) .
      qq( <a href="#bar">or bar</a>) .
      '<br>'x80 . "\n" .
      qq(<a name="foo">welcome to foo</a>) .
      qq( would you like to <a href="#bar">visit bar</a>) .
      qq( or go back to <a href="#top">the top</a>) .
      qq(</p>) . "\n".
      '<p>'.'<br>'x80 . "\n" .
      qq(<a name="bar">welcome to bar</a></p>) .
      qq( ... off to <a href="#foo">foo</a>) .
      qq( or go back to <a href="#top">the top</a>) .
      '<br>'x80 .
      '';
  }
  elsif(0) { # more hackery
    if(defined($ENV{THOUT_HOME})) {
      $self->htmlwidget->LoadURL($ENV{THOUT_HOME});
    }
    else {
      use dtRdr::Hack;
      $greeting .= dtRdr::Hack->get_widget_img();
      $greeting =
        qq(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">).
        "<html><body>$greeting</body></html>";
      $self->htmlwidget->SetPage($greeting);
    }
  }
  else { # TODO something nicer here
    $greeting =
      qq(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">).
      "<html><body>Welcome to DotReader!</body></html>";
    $self->htmlwidget->SetPage($greeting);
  }

} # end subroutine show_welcome definition
########################################################################

=head1 GUI Control

=head2 enable

  $bvm->enable('_profile');

=head2 disable

  $bvm->disable('_profile');

=cut

sub enable  {$_[0]->{main_frame}->enable($_[1]);}
sub disable {$_[0]->{main_frame}->disable($_[1]);}

=head1 Hacks

The multi-view needs to be finished, at which point more of this will
make more sense.

=head2 load_url

This API is probably stable, but the behavior will definitely change.
Currently, this just loads directly in the widget unless there is a book
open.

  $self->load_url($url);

=cut

sub load_url {
  my $self = shift;
  my ($url) = @_;
  if(my $bv = $self->book_view) {
    $bv->load_url($url);
  }
  else {
    $self->htmlwidget->load_url($url);
  }
} # end subroutine load_url definition
########################################################################

=head1 Book

=head2 open_book

  $bvm->open_book($book);

=cut

sub open_book {
  my $self = shift;
  my ($book) = @_;

  $self->note_viewer->no_note;
  # TODO clear search results?

  # TODO if we have a book_view, freeze it, etc
  $self->{book_view} and warn "\n\nnot done\n\n ";

  # create and init the bookview
  my $bv = $self->{book_view} = dtRdr::GUI::Wx::BookView->new($book);
  $bv->init($self);
  my $sidebar = $self->sidebar;
  $bv->set_widgets(
    book_tree      => $sidebar->contents,
    note_tree      => $sidebar->notes,
    bookmark_tree  => $sidebar->bookmarks,
    highlight_tree => $sidebar->highlights,
    htmlwidget     => $self->htmlwidget
  );

  $self->anno_io->apply_to($book);
  { # populate the sidebar trees
    my @trees = qw(
      book
      note
      bookmark
      highlight
    );
    foreach my $tree (@trees) {
      my $attrib = $tree . '_tree';
      $bv->$attrib->populate($book);
    }
  }

  $bv->render_node_by_id($book->toc->id);
  $self->enable('_book');
  $self->disable('navigation_page_up');
  $self->disable('file_add_book'); # default to disabled
  # sorry, we can't handle going back to a destroyed view object yet
  $self->disable('_history');
  $self->sidebar->select_item('contents');
} # end subroutine open_book definition
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
