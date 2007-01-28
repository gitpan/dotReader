package dtRdr::GUI::Wx::Frame;
$VERSION = eval{require version}?version::qv($_):$_ for(0.10.1);

use warnings;
use strict;


use dtRdr;
use dtRdr::Logger;
use dtRdr::GUI::Wx::State;
use dtRdr::GUI::Wx::Utils qw(_accel);
use dtRdr::GUI::Wx::Sidebar;
use dtRdr::GUI::Wx::Plugins;

use WxPerl::MenuMaker;
use MultiTask::Manager;
use YAML::Syck;

use Wx;
use base qw(Wx::Frame);

use constant {
  SIDEBAR_MINSIZE => 1,
  SIDEBAR_DROPSIZE => 157,
};

use Wx (
  ':everything',
  qw(
  wxBITMAP_TYPE_PNG
  wxSPLASH_CENTRE_ON_PARENT
  wxSPLASH_TIMEOUT
  wxDefaultPosition
  wxDefaultSize
  wxSIMPLE_BORDER
  wxFRAME_TOOL_WINDOW
  wxFRAME_NO_TASKBAR
  wxSTAY_ON_TOP
  wxACCEL_CTRL
  wxACCEL_SHIFT
  WXK_F2
  WXK_F5
  WXK_F6
  WXK_F7
  WXK_F8
  WXK_F9
  WXK_F10
  wxID_EXIT
  wxOK
  wxICON_INFORMATION
  ));

use Wx::Event qw(
  EVT_TREE_ITEM_MENU
  EVT_CONTEXT_MENU
  EVT_TREE_ITEM_ACTIVATED
  EVT_TREE_SEL_CHANGED
  EVT_SIZE
  EVT_IDLE
  EVT_MENU
  EVT_SPLITTER_SASH_POS_CHANGED
  EVT_SPLITTER_SASH_POS_CHANGING
  EVT_SPLITTER_DOUBLECLICKED
  EVT_NOTEBOOK_PAGE_CHANGED
);

########################################################################
use Method::Alias ();
# $mk_alias->($is_also, $original);
my $mk_alias = sub { Method::Alias->import(@_); };
########################################################################

use Class::Accessor::Classy;
ro qw(
  bv_manager
  frame_main_statusbar
  sizer_1
  sizer_3
  window_1
  sidebar
  right_window
  note_viewer_pane
  note_viewer_sizer
  nv_htmlwidget
  nv_title_bar
  nv_button_goto
  nv_button_edit
  nv_button_delete
  nv_button_close
  sb_htmlwidget
);

$mk_alias->(note_viewer    => 'note_viewer_pane');
$mk_alias->(status_bar     => 'frame_main_status_bar'); # temp

# non-glade accessors go here
# (XXX everything is non-glade now, but we're transitioning)
ro qw(
  state
  menumap
  taskmaster
);
rw 'splash_screen';
no  Class::Accessor::Classy;
########################################################################
########################################################################
########################################################################

=head1 NAME

dtRdr::GUI::Wx::Frame - base class for the main frame

=head1 SYNOPSIS

This gives finer-grained control than inheriting Wx::Frame directly.

=cut


=head1 Constructor

=head2 new

  $frame = dtRdr::GUI::Wx::Frame->new(
              $parent,
              $id,
              $title,
              $pos,
              $size,
              $style,
              $name
              );

=cut

sub new {
  my $self = shift;
  my ($parent, $id, $title, $pos, $size, $style, $name) = @_;
  # XXX not setting defaults here, but maybe should --Eric

  $self = $self->SUPER::new(
    $parent, $id, $title, $pos, $size, $style, $name
    );

  if(0) { # splash now handled by app.pl
    $self->make_splash();
    my $now = Time::HiRes::time();
    WARN "splash is out in ", $now - $dtRdr::start_time, " seconds\n";
  }

  return($self);
} # end subroutine new definition
########################################################################

=head1 Methods

=head2 init

  $frame->init;

=cut

sub init {
  my $self = shift;

  # setup the state object
  $self->{state} = dtRdr::GUI::Wx::State->new(
    # better way to setup the defaults? (eventually they'll be on disk anyway)
    sidebar_position => $self->window_1->GetSashPosition,
    sidebar_open     => 1,
    notebar_open     => 0,
    notebar_position => 80,
  );

  # don't allow splitter window to unsplit at all
  $self->window_1->SetMinimumPaneSize(SIDEBAR_MINSIZE);
  $self->right_window->SetMinimumPaneSize(1);
  $self->right_window->SetSashGravity(1.0);

  $self->bv_manager->init($self);
  $self->sidebar->init($self);
  $self->init_menumap;
  $self->setup;
  $self->note_viewer->init($self);
  $self->note_viewer->setup;

  $self->sidebar->libraries->populate;

  # XXX why doesn't this work on WxMozilla
  0 and WARN "focus is on '", Wx::Window::FindFocus() || 'nil', "'";

  $self->sidebar->select_item('libraries');

  # turns-on the adclient -- needs better name/home
  #$self->sidebar->_ad_split;

  $self->disable('_book');
  $self->disable('file_add_book');
  $self->disable('_history');

  { # setup the idle event
    my $master = $self->{taskmaster} = MultiTask::Manager->new(
      on_add => sub {Wx::WakeUpIdle()},
    );

    my $is_working = 0; # only here for diagnostics
    EVT_IDLE($self, sub {
      my ($obj, $evt) = @_;
      if($master->has_work) {
        $is_working = 1;
        $master->work; Wx::WakeUpIdle() if($master->has_work);
      }
      else { # no work to do
        $is_working and warn "no workers";
        $is_working = 0;
      }
      $evt->Skip;
    });
  } # idle

} # init
########################################################################

=head2 init_menumap

Build the menu map.

  $self->init_menumap;

=cut

sub init_menumap {
  my $self = shift;
  my $mm = $self->{menumap} = WxPerl::MenuMaker->new(
    handler => $self,
    nomethod => sub {
      L('menu')->debug("missing method $_[0]()");
    }
  );
  my ($menu_data) = YAML::Syck::LoadFile(dtRdr->data_dir . 'menu.conf');
  my @menu = @{$menu_data->{menubar}};
  $mm->create_menubar(\@menu);
  my @toolbar = @{$menu_data->{toolbar}};
  foreach my $item (@toolbar) {
    unless($item->{icon}) {
      $item->{separator} or
        die("no icon: $item->{name} (", join(", ", %$item), ")");
      next;
    }
    $item->{icon} =
      # XXX this needs to look in the user directory too
      # XXX dtRdr->find_icon ?
      dtRdr->data_dir . 'gui_default/icons/' .
      $item->{icon};
  }
  $mm->create_toolbar(\@toolbar);
  return($mm);
} # end subroutine init_menumap definition
########################################################################

=head1 Misc

=head2 setup

Sets-up event handlers and such

  $self->setup;

=cut

sub setup {
  my $self = shift;


  EVT_SPLITTER_SASH_POS_CHANGED($self, $self->window_1,
    sub { $self->sidebar_changed($_[1])}
  );
  EVT_SPLITTER_DOUBLECLICKED($self, $self->window_1,
    sub { $self->sidebar_toggle() }
  );

  # Hacky stuff {{{
  if(1 and my $name = $ENV{PAR_ARGV_0}) {
    $name =~ s/\.[^\.]+$//;
    $name =~ s#\\+#/#g;
    $name =~ s#.*/##g;
    $self->SetTitle($name);
  }
  # end Hacky stuff }}}

  # NOTE please use menu_<foo> methods here wherever possible
  my $acc_table = Wx::AcceleratorTable->new(
    map({$self->_accel(@$_)}
      ['F2', 'activate_sidebar'],
      ['F3', 'activate_reader'],
      ['CTRL+L', 'menu_view_tab_libraries'], # TODO rethink
      ['CTRL+R', 'menu_view_tab_contents'],  # TODO rethink
      ['F8',  'menu_view_toggle_notebar'],
      # F7 is _resize
      ['F9',  'menu_view_toggle_sidebar'],
      # XXX wx won't give me F10! grr.
      ['CTRL+W', 'menu_file_exit'],
      ['CTRL+H', 'menu_tb_highlight'],
      ['CTRL+J', 'menu_tb_note'],
      ['CTRL+K', 'menu_tb_bookmark'],
      # ANYTHING BELOW HERE IS A HACK
      ['F7', '_resize'],
      ['CTRL+SHIFT+F5', sub { dtRdr->_reload; $self->setup}],
      ['CTRL+A', sub {$self->sidebar->_ad_split}],
      ['CTRL+G', sub { $self->bv_manager->show_welcome}],
      ['CTRL+F', sub {
        # Hey, find actually works!
        ($^O eq 'linux') or return;
        my $hw = $self->bv_manager->htmlwidget;
        WARN $hw->Find('bob', 1, 1, 1, 0)
      }],
    ), # end map
    #[wxACCEL_CTRL, ord('C'), wxID_COPY, ], # copy (XXX doesn't belong here)
  );

  # and set it active on everything
  $_->SetAcceleratorTable($acc_table) for(
    #map({$self->$_} qw(
    #  bv_manager
    #  window_1
    #)),
    # TODO widgets grabbing keys issues need work
    $self->bv_manager->htmlwidget,
    $self,
  );

  if(1) { # set some hotkeys local to the sidebar
    my $mod = 'ALT+'; # XXX GRR :-/
    my $sidebar_acc_table = Wx::AcceleratorTable->new(
      map({$self->_accel(@$_)}
        [$mod . 'L', 'menu_view_tab_libraries'],
        [$mod . 'C', 'menu_view_tab_contents'],
        [$mod . 'S', 'menu_view_tab_search'],
        [$mod . 'N', 'menu_view_tab_notes'],
        [$mod . 'B', 'menu_view_tab_bookmarks'],
        [$mod . 'I', 'menu_view_tab_highlights'],
      )
    );
    $self->sidebar->SetAcceleratorTable( $sidebar_acc_table);
  }

  Wx::Event::EVT_CLOSE($self, sub {
    $_[1]->Skip;
    $self->taskmaster->quit_all;
  });

  $self->_disable_not_dones;

  my $plugins = dtRdr::GUI::Wx::Plugins->new;
  $plugins->init($self);

} # end subroutine setup definition
########################################################################
{ my $size = Wx::Size->new(700,250);
sub _resize { my $self = shift; my ($event) = @_;
  my $sz = $size; $size = $self->GetSize; $self->SetSize($sz);
}}


=head2 _disable_not_dones

  $self->_disable_not_dones;

=cut

sub _disable_not_dones {
  my $self = shift;
  my @nots = qw(
    view_refresh
    view_source
    notes_private_notes_export_current
    notes_private_notes_export_all
    notes_private_notes_import
    notes_public_notes_create
    notes_public_notes_download
    notes_servers_add
    help_update
    toolbar.help
  );
  foreach my $not (@nots) {
    $self->disable($not);
  }
} # end subroutine _disable_not_dones definition
########################################################################

=head2 setup_progressbar

  $self->setup_progressbar;

=cut

sub setup_progressbar {
  my $self = shift;
  { # statusbar hack
    my $sb = $self->frame_main_statusbar;
    Wx::Event::EVT_SIZE($sb, sub {
      WARN "size";
      my $rect = $sb->GetFieldRect(0);
      unless($self->{mygauge}) {
        $self->{mygauge} = Wx::Gauge->new($sb, -1,
          100_000,
          [-1,-1],[-1,-1],
          wxGA_HORIZONTAL|wxFULL_REPAINT_ON_RESIZE
        );
        #$gauge->Show(1);
      }
      my $gauge = $self->{mygauge};
      #$gauge->Move($rect->GetPosition);
      $gauge->SetSize($rect->GetSize);
      $gauge->SetSize($rect);
      $gauge->SetValue(50_000);
      $sb->Refresh;
      #$gauge->SetBackgroundColour(Wx::Colour->new(255, 0, 0));
    }
    );
  }
  # TODO SetStatusWidths(-3,-1,-1,-1) (once we get rid of glade)
} # end subroutine setup_progressbar definition
########################################################################

=head1 Sidebar Control

=head2 sidebar_changed

  $self->sidebar_changed($event);

=cut

sub sidebar_changed {
  my $self = shift;
  my ($event) = @_;

  my $state = $self->state;
  # ok, this only fires on manual drags and not SetSashPosition() ?
  my $new_pos = $event->GetSashPosition;
  # WARN("pos changed to $new_pos");

  # TODO add some gravity 10px around the button width
  if($new_pos < SIDEBAR_DROPSIZE) { # it's mostly useless after even 200
    # meh, call it a draggy-toggle and DWIM
    if($state->sidebar_open) { # you meant close, right?
      $self->sidebar_close;
    }
    else { # magic open
      # (un?)fortunately, this means the doubleclick is not needed from
      # the closed position.  Is that inconsistent?
      $self->sidebar_open;
    }
  }
  else {
    # remember the new position
    $state->set_sidebar_position($new_pos);
    $state->set_sidebar_open(1); # just in case
  }

  # move the keyboard focus just in case
  $state->sidebar_open or $self->activate_reader;
} # end subroutine sidebar_changed definition
########################################################################

=head2 sidebar_toggle

  $self->sidebar_toggle($event);

=cut

sub sidebar_toggle {
  my $self = shift;
  my ($event) = @_;

  my $method =
    $self->state->sidebar_open ? 'sidebar_close' : 'sidebar_open';
  $self->$method;

} # end subroutine sidebar_toggle definition
########################################################################

=head2 sidebar_open

  $frame->sidebar_open

=cut

sub sidebar_open {
  my $self = shift;

  my $state = $self->state;
  $state->set_sidebar_open(1);
  $self->window_1->SetSashPosition($state->sidebar_position);
  $self->sidebar->SetFocus;
} # end subroutine sidebar_open definition
########################################################################

=head2 sidebar_close

  $frame->sidebar_close

=cut

sub sidebar_close {
  my $self = shift;

  my $state = $self->state;
  $state->set_sidebar_open(0);
  # NOTE mac gets silly about this if SashPosition is less than 3
  $self->window_1->SetSashPosition(SIDEBAR_MINSIZE);
  $self->activate_reader;
} # end subroutine sidebar_close definition
########################################################################

=head2 activate_sidebar

  $frame->activate_sidebar($event);

=cut

sub activate_sidebar {
  my $self = shift;
  my ($event) = @_;

  $self->sidebar_open;
} # end subroutine activate_sidebar definition
########################################################################

=head2 activate_reader

  $frame->activate_reader($event);

=cut

sub activate_reader {
  my $self = shift;
  $self->bv_manager->htmlwidget->SetFocus;
} # end subroutine activate_reader definition
########################################################################

=head1 Menu Events

=head2 menu_file_open

  $frame->menu_file_open($event);

=cut

sub menu_file_open {
  my $self = shift;
  my ($event) = @_;

  my $filename = Wx::FileSelector(
    "Choose a file to open", , , , , $self, -1, -1
  );
  if($filename) {
    $self->backend_file_open($filename);
  }
} # end subroutine menu_file_open definition
########################################################################

=head2 backend_file_open

  $frame->backend_file_open($filename);

=cut

sub backend_file_open {
  my $self = shift;
  my ($filename) = @_;
  (-e $filename) or die "no file '$filename'";

  $self->frame_main_statusbar->SetStatusText('Loading '.$filename, 0);

  # this will get us by until config is operable
  # (and shouldn't break after it works either)
  require dtRdr::Plugins::Book; dtRdr::Plugins::Book->init();

  # TODO break this down a bit and set a callback for status
  my $book = eval { dtRdr::Book->new_from_uri($filename) };
  if($@) {
    $self->error("problem loading book '$filename'\n$@");
    return;
  }
  $self->bv_manager->open_book($book);
  $self->enable('file_add_book');
  $self->activate_reader;
  $self->frame_main_statusbar->SetStatusText('', 0);
} # end subroutine backend_file_open definition
########################################################################

=head2 _open_first_book

A hack.

  $frame->_open_first_book;

=cut

sub _open_first_book {
  my $self = shift;

  my $tr = $self->sidebar->libraries;

  # XXX this is stupid, but the library needs to get smarter about
  # reusing items so that the object ref can be the librarytree id
  if(1) {
    my $id = $tr->GetRootItem;
    $tr->Expand($id);
    ($id) = $tr->GetFirstChild($id); # My Libraries
    $tr->Expand($id);
    ($id) = $tr->GetFirstChild($id); # default library
    $tr->SelectItem($id); # quickstart
  }

  my ($library) = dtRdr->user->get_libraries();
  my ($data) = $library->get_book_info();
  my $book = $library->open_book(id => $data->id);
  $self->bv_manager->open_book($book);
  $self->activate_reader;
} # end subroutine _open_first_book definition
########################################################################

=head2 menu_file_add_book

  $frame->menu_file_add_book;

=cut

sub menu_file_add_book {
  my $self = shift;

  # Note the enable in backend_file_open() and disable in
  # BvManager.open_book -- we should only be adding books that are not
  # in a library.
  my $bvm = $self->bv_manager;
  my $bv = $bvm->book_view or return;
  my $book = $bv->book;

  # TODO some options here
  my (@libraries) = dtRdr->user->get_libraries();

  $book->add_to_library($libraries[0]);

  # TODO this is silly
  my $tr = $self->sidebar->libraries;
  $tr->DeleteAllItems;
  $tr->populate;
  $self->disable('file_add_book');
} # end subroutine menu_file_add_book definition
########################################################################

=head2 menu_file_exit

Close.

=cut

$mk_alias->(menu_file_exit => 'Close');
########################################################################

=head2 menu_view_source

Display the document source.

  $frame->menu_view_source;

=cut

sub menu_view_source {
  my $self = shift;

  my $bvm = $self->bv_manager;
  # we might not be started/setup
  my $bv = $bvm->book_view or return;
  defined($ENV{EDITOR}) or die "you have no editor";
  local $ENV{THOUT_EDITOR} = $ENV{EDITOR};
  dtRdr::Logger->editor($bv->htmlwidget->html_source);
} # end subroutine menu_view_source definition
########################################################################

=head2 menu_view_toggle_sidebar

=cut

sub menu_view_toggle_notebar {$_[0]->note_viewer->notebar_toggle};
$mk_alias->( menu_view_toggle_sidebar => 'sidebar_toggle' );
########################################################################

# the sub menu_view_tab_<foo> callbacks
foreach my $item (dtRdr::GUI::Wx::Sidebar->core_attribs) {
  my $subname = 'menu_view_tab_' . $item;
  my $subref = sub {
    my $self = shift;
    $self->sidebar->select_item($item);
    $self->sidebar_open;
  };
  no strict 'refs';
  *{$subname} = $subref;
} # end menu_view_tab_<foo> creation
########################################################################

=head2 menu_view_zoom_in

  $frame->menu_view_zoom_in

=cut

sub menu_view_zoom_in {
  my $self = shift;
  my ($event) = @_;
  return unless $self->bv_manager->book_view;
  $self->bv_manager->htmlwidget->increase_font;
} # end subroutine menu_view_zoom_in definition
########################################################################

=head2 menu_view_zoom_out

  $frame->menu_view_zoom_out

=cut

sub menu_view_zoom_out {
  my $self = shift;
  my ($event) = @_;
  return unless $self->bv_manager->book_view;
  $self->bv_manager->htmlwidget->decrease_font;
} # end subroutine menu_view_zoom_out definition
########################################################################

=head2 menu_navigation_history_back

  $self->menu_navigation_history_back($event);

=cut

sub menu_navigation_history_back {
  my $self = shift;
  my ($event) = @_;

  my $bvm = $self->bv_manager;

  # we might not be started/setup
  my $bv;
  ($bv = $bvm->book_view and $bv->history) or return;

  # or maybe no history item to go to
  unless($bv->history->has_prev) {
    # TODO History back button should be disabled
    return;
  }

  $bv->history_back;
} # end subroutine menu_navigation_history_back definition
########################################################################

=head2 menu_navigation_history_next

  $self->menu_navigation_history_next($event);

=cut

sub menu_navigation_history_next {
  my $self = shift;
  my ($event) = @_;

  L->debug('history_next');
  my $bvm = $self->bv_manager;

  # we might not be started/setup
  my $bv;
  ($bv = $bvm->book_view and $bv->history) or return;

  # or maybe no history item to go to
  unless($bv->history->has_next){
    # TODO History next button should be disabled
    return;
  }

  $bv->history_next;
} # end subroutine menu_navigation_history_next definition
########################################################################

=head2 menu_help_license

  $frame->menu_help_license;

=cut

sub menu_help_license {
  my $self = shift;
  use dtRdr::GUI::Wx::Dialog::License;
  dtRdr::GUI::Wx::Dialog::License->new($self)->init($self)->ShowModal;
} # end subroutine menu_help_license definition
########################################################################

=head2 menu_help_about

  $frame->menu_help_about;

=cut

sub menu_help_about {
  my $self = shift;

  # TODO get program name
  my $text =
    'This is dotReader ' . dtRdr->release_number .  '.';
  my $dialog = Wx::MessageDialog->new(
    $self,
    $text,
    'About DotReader',
    wxOK|wxICON_INFORMATION
  );
  $dialog->ShowModal;

} # end subroutine menu_help_about definition
########################################################################

=head1 Toolbar Events

=head2 menu_tb_highlight

  $frame->menu_tb_highlight($event);

=cut

sub menu_tb_highlight {
  my $self = shift;
  my ($event) = @_;

  my $bv = $self->bv_manager->book_view;
  # TODO we need to disable this button if there's no book
  $bv or return; # nothing to highlight
  $bv->highlight_at_selection;
} # end subroutine menu_tb_highlight definition
########################################################################

=head2 menu_tb_note

  $frame->menu_tb_note($evt);

=cut

sub menu_tb_note {
  my $self = shift;
  my ($evt) = @_;

  my $bv = $self->bv_manager->book_view;
  # TODO we need to disable this button if there's no book
  $bv or return;
  $bv->note_at_selection;
} # end subroutine menu_tb_note definition
########################################################################

=head2 menu_tb_bookmark

  $self->menu_tb_bookmark($event);

=cut

sub menu_tb_bookmark {
  my $self = shift;
  my ($evt) = @_;

  my $bv = $self->bv_manager->book_view;
  unless($bv) { # assert
    $self->error("You must open a book before you can add highlights");
    return;
  }
  $bv->bookmark_at_selection;
} # end subroutine menu_tb_bookmark definition
########################################################################

=head2 menu_file_print

  $self->menu_file_print_page($event);

=cut

sub menu_file_print_page {
  my $self = shift;
  my ($event) = @_;
  # TODO disable this if print is not allowed
  $self->bv_manager->htmlwidget->print_page();
} # end subroutine menu_file_print_page definition
########################################################################

=head2 menu_navigation_page_up

  $frame->menu_navigation_page_up($event)

=cut

sub menu_navigation_page_up {
  my $self = shift;
  my ($event) = @_;
  return unless $self->bv_manager->book_view;
  $self->bv_manager->book_view->render_prev_page;
  #$self->bv_manager->htmlwidget->scroll_page_bottom();


  #$self->bv_manager->htmlwidget->scroll_page_up() or WARN("couldn't scroll");
} # end subroutine menu_navigation_page_up definition
########################################################################

=head2 menu_navigation_page_down

  $frame->menu_navigation_page_down($event)

=cut

sub menu_navigation_page_down {
  my $self = shift;
  my ($event) = @_;
  return unless $self->bv_manager->book_view;
  $self->bv_manager->book_view->render_next_page;
  $self->enable('navigation_page_up'); # allowed now
} # end subroutine menu_navigation_page_down definition
########################################################################

=head1 Overridden Methods

=head2 Show

Currently assumes that new() did make_splash();

  $frame->Show(1);

=cut

sub Show {
  my $self = shift;
  my $ret = $self->SUPER::Show(@_);
  $self->kill_splash;
  #warn "focus is on '", Wx::Window::FindFocus() || 'nil', "'";
  dtRdr->_init_reloader;
  return($ret);
} # end subroutine Show definition
########################################################################

=head2 error

  $self->error($message);

=cut

sub error {
  my $self = shift;
  my ($message) = @_;
  Wx::MessageBox($message, 'Error', wxSTAY_ON_TOP, $self);
} # end subroutine error definition
########################################################################

=head2 enable

Turn on an item or profile.

  $frame->enable($item);

=head2 disable

Turn off an item or profile.

  $frame->disable($item);

=head2 _enabler

  $self->_enabler($name, $val);

=cut

sub enable {$_[0]->_enabler($_[1], 1);}
sub disable {$_[0]->_enabler($_[1], 0);}
sub _enabler {
  my $self = shift;
  my ($prof, $val) = @_;
  defined($prof) or croak('must have an item');
  defined($val) or croak('must have a value');

  # linkage happens first
  my @linkage = (
    { # on disable
      _book => [qw(
        _no_drm
      )],
    },
    { # on enable (i.e. 1)
    }
  );
  if(my $list = $linkage[$val]{$prof}) {
    foreach my $item (@$list) {
      $self->_enabler($item, $val);
    }
  }

  # refer to the menu item
  # if there is no menu item, use toolbar.<name>
  my %profiles = (
    _book => [qw(
      toolbar.note
      toolbar.bookmark
      toolbar.highlight
      navigation_page_up
      navigation_page_down
      view_tab_contents
      view_tab_search
      view_tab_notes
      view_tab_bookmarks
      view_tab_highlights
    )],
    # disable('_no_drm') turns these off
    _no_drm => [qw(
      view_source
    )],
    _history => [qw(
      navigation_history_next
      navigation_history_back
    )],
  );
  # see menu_map for associations

  # check for a profile
  if(my $list = $profiles{$prof}) {
    foreach my $item (@$list) {
      # TODO allow it to be a subref?
      $self->_enabler($item, $val);
    }
    return;
  }

  # not a profile, so get the menuitem and switch it
  my $mm = $self->menumap;
  my $path_1 = 'menu_items';
  my $path_2 = 'toolbar_items';
  my $associated = 'associated_tool';
  my $do_1 = sub { $_[0]->Enable($_[1]); };
  my $do_2 = sub {$mm->toolbar->EnableTool($_[0]->GetId, $_[1])};
  if($prof =~ s/^toolbar\.//) {
    $associated = 'associated_menu';
    ($path_1, $path_2) = ($path_2, $path_1); # swaps
    ($do_1, $do_2) = ($do_2, $do_1);
  }
  my $item = $mm->$path_1->$prof;
  $do_1->($item, $val);
  $associated = $mm->$associated;
  if($associated->can($prof)) {
    my $lookup = $associated->$prof;
    $do_2->($mm->$path_2->$lookup, $val);
  }
} # end subroutine _enabler definition
########################################################################

=head1 Splash stuff

=head2 make_splash

Not currently for public consumption.

  $frame->make_splash();

=cut

sub make_splash {
  my $self = shift;
  my ($timeout) = @_;

  my $bitmap = Wx::Bitmap->new(
    dtRdr->data_dir . 'gui_default/images/splash.png',
    wxBITMAP_TYPE_PNG
    );

  $timeout ||= 0;
  my $sp = Wx::SplashScreen->new(
    $bitmap,
    # XXX wxSPLASH_TIMEOUT causes segfault
    #wxSPLASH_CENTRE_ON_PARENT|wxSPLASH_TIMEOUT,
    wxSPLASH_CENTRE_ON_PARENT,
    $timeout,
    $self,
    -1, wxDefaultPosition, wxDefaultSize,
    wxSIMPLE_BORDER|wxFRAME_NO_TASKBAR|wxSTAY_ON_TOP
    );
  Wx::Yield();
  $self->{splash_screen} = $sp;
  return(1);
} # end subroutine make_splash definition
########################################################################

=head2 kill_splash

  $frame->kill_splash;

=cut

sub kill_splash {
  my $self = shift;
  # destroy the splash after the Show() succeeds
  exists($self->{splash_screen}) or die "splash screen is already gone";
  my $sp = delete($self->{splash_screen});
  return($sp->Destroy);
} # end subroutine kill_splash definition
########################################################################


=head1 AUTHOR

Eric Wilhelm <ewilhelm at cpan dot org>

http://scratchcomputing.com/

=head1 COPYRIGHT

Copyright (C) 2006 Eric L. Wilhelm and Osoft, All Rights Reserved.

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
