package dtRdr::Book;

use warnings;
use strict;

use Carp;
use XML::Parser::Expat;
use Digest::MD5;
use URI;
use English '-no_match_vars';

our $VERSION = 0.01;

use dtRdr::Plugins::Book;
use dtRdr::TOC;
use dtRdr::Metadata;
use dtRdr::String::Splicer;
use dtRdr::Logger;
use dtRdr::Callbacks::Book;
use dtRdr::Selection;

use dtRdr::Traits::Class qw(
  NOT_IMPLEMENTED
  );

use dtRdr::Accessor;
dtRdr::Accessor->ro(qw(
  notes
  bookmarks
  highlights
  selections
  toc
));
dtRdr::Accessor->rw(qw(
  id
  title
  library
  anno_io
));
my $set_fingerprint = dtRdr::Accessor->ro_w('fingerprint');

# the callbacks object is class data
dtRdr::Accessor->class_ro(callbacks => dtRdr::Callbacks::Book->new());

use Method::Alias qw(
  has_cached_NC has_cached_node_characters
  get_cached_NC get_cache_chars
  get_NC        get_node_characters
  create_NC     create_node_characters
  cache_NC      cache_node_characters
);

=head1 NAME

dtRdr::Book - base and factory class for books

=head2 import

  dtRdr::Book->import(%arguments);

Called by 'use dtRdr::Book (%arguments)'.  Only applicable to plugins.

=over 1

=item register HASHREF

A hash reference which is passed to register_plugin().

  use dtRdr::Book (register => {});

  use dtRdr::Book (register => {foo => "bar"});

=back

=cut

sub import {
  my $self = shift;
  my @args = @_;

  # only do something if requested
  @args or return();

  (@args %2) and croak("odd number of elements in argument hash");
  my %args = @args;


  $args{register} or return(); # XXX until we learn new tricks at least

  $args{'register'}{'class'} ||= caller;
  # just like: use dtRdr::Book ( register => {class => __PACKAGE__} );
  $self->register_plugin(%{$args{register}});
} # end subroutine import definition
########################################################################

=head2 register_plugin

Registers your plugin with dtRdr::Plugins::Book.

  dtRdr::Book->register_plugin(%args);

=cut

sub register_plugin {
  my $self = shift;
  (@_ %2) and croak("odd number of elements in argument hash");
  my %args = @_;

  $args{'class'} ||= caller;

  dtRdr::Plugins::Book->add_class(%args);
} # end subroutine register_plugin definition
########################################################################

=head1 Factory Methods

=cut

# TODO:
#   new_by_uri       - creates object but doesn't load
#   identify_by_foo  - $_->identify_foo for (@plugins)

=head2 new_from_uri

Create a new object and load the uri.

  dtRdr::Book->new_from_uri($uri);

=cut

sub new_from_uri {
  my $self = shift;
  my ($uri) = @_;

  my ($class, $cache) = $self->identify_by_uri($uri);
  if($class) {
    my $book = $class->new();

    # $cache should always have only one key
    my ($cache_key, @o) = keys(%$cache);
    @o and die "'$class' overfilled the cache in identify_uri()";

    # see if it has a cache-utilizing constructor method
    my $method = $cache_key ? "load_from_$cache_key" : 'load_uri';
    $method = 'load_uri' unless($book->can($method));
    $book->$method( ($cache_key ? $cache->{$cache_key} : $uri))
      or die "factory call to $book->$method failed";
    # XXX and then try more plugins?
    return($book);
  }

  die "could not find a suitable plugin for '$uri'";
} # end subroutine new_from_uri definition
########################################################################

=head2 identify_by_uri

  my $class = dtRdr::Book->identify_by_uri($uri);

=cut

sub identify_by_uri {
  my $self = shift;
  my ($uri) = @_;

  # FIXME make cache a passed-in reference
  # (so we can call this from elsewhere and not deal with that)

  my @plugins = dtRdr::Plugins::Book->get_classes();
  @plugins or die("no book plugins defined");
  my %cache;
  foreach my $class (@plugins) {

    RL('#plugin')->debug("Loading Plugin $class");
    if(my $ref = $class->can('identify_uri')) {
      if($ref eq __PACKAGE__->can('identify_uri')) {
        RL('#plugin')->warn("$class unfinished");
        # XXX de-register?
        next;
      }
    }
    else {
      # XXX de-register?
      RL('#plugin')->warn("$class is incompetent");
      next;
    }
    # warn "ask $class";

    # optimizes repassing objects if the identify_ method in one plugin
    # creates one -- also: skip those that don't work with that type of
    # object?
    my ($res, $res_c) = $class->identify_uri( $uri, %cache ? {%cache} : ());

    $res and return($class, ($res_c ? ($res_c) : {}));
    L->debug("$class declined $uri");

    %cache = ($res_c ? (%$res_c) : ()); # no return -> drop existing cache
  }
  return();
} # end subroutine identify_by_uri definition
########################################################################

=head1 Base Class API

=head1 Constructor

=head2 new

  $book = dtRdr::Book->new();

=cut

sub new {
	my $package = shift;
	my $class = ref($package) || $package;
	my $self = {};
  my %defaults = (
    metadata    => dtRdr::Metadata->new,
    cache_chars => {},
    highlights  => {},
    bookmarks   => {},
    notes       => {},
    selections  => {},
  );
  foreach my $k (keys(%defaults)) { $self->{$k} = $defaults{$k}; }
	bless($self, $class);
	return($self);
} # end subroutine new definition
########################################################################

=head1 Virtual Methods

Subclasses need to implement these.

=head2 load_uri

  $book->load_uri($uri);

=cut

sub load_uri { $_[0]->NOT_IMPLEMENTED(@_[1..$#_]); }

=head2 identify_uri

  $book->identify_uri();

=cut

sub identify_uri { $_[0]->NOT_IMPLEMENTED(@_[1..$#_]); }


=head2 member_exists

  my $bool = $book->member_exists($filepath);

=cut

sub member_exists { $_[0]->NOT_IMPLEMENTED(@_[1..$#_]); }

=head2 get_member_string

Gets the string for the member at path $filepath.

  my $string = $book->get_member_string($filepath);

=cut

sub get_member_string { $_[0]->NOT_IMPLEMENTED(@_[1..$#_]); }

=head2 get_content

Returns the HTML and associated image and object data for a portion of
the book.

  my $html = $book->get_content($toc)

The C<$toc> object is a (C<'dtRdr::TOC'>) node representing the content
location.

=cut

sub get_content { my $self = shift; $self->NOT_IMPLEMENTED(@_); }

=head2 get_content_by_id

  my $html = $book->get_content_by_id($id);

=cut

sub get_content_by_id { my $self = shift; $self->NOT_IMPLEMENTED(@_); }

=head2 get_raw_content

Unprocessed content for a given node.

  $book->get_raw_content($toc);

=cut

sub get_raw_content { my $self = shift; $self->NOT_IMPLEMENTED(@_); }

=head2 get_copy_content

Copyable content for a given node.

  $book->get_copy_content($toc);

=cut

sub get_copy_content { my $self = shift; $self->NOT_IMPLEMENTED(@_); }

=head2 get_trimmed_content

Gets all of the rendered xml content for a $toc node.

  my $xml = $book->get_trimmed_content($toc);

=cut

sub get_trimmed_content { my $self = shift; $self->NOT_IMPLEMENTED(@_); }

=head2 is_nesty

A class method that says whether the book needs special treatment.

=cut

sub is_nesty { my $self = shift; $self->NOT_IMPLEMENTED(@_); }

=head1 Methods

=cut

=head2 mk_fingerprint

Create and store a checksum for the book.

  $book->mk_fingerprint($stringref);

=cut

sub mk_fingerprint {
  my $self = shift;
  my ($data) = @_;

  my $digest = Digest::MD5->new;

  # TODO $data could be a filehandle, filename, etc
  if(ref($data) eq 'SCALAR') {
    $digest->add($$data);
  }
  else {
    croak('must have a scalar reference');
  }
  $self->$set_fingerprint( $digest->hexdigest );
} # end subroutine mk_fingerprint definition
########################################################################

=head2 add_metadata UNUSED?

  $book->add_metadata($metadata)

Add the metadata element to the book. This will insert the metadata
item into the metadata cache for the library this book object came
from.

=cut

sub add_metadata {
  my ($self, $metadata) = @_;

  do('./util/BREAK_THIS') or die;
  # XXX cache of what where?
  my $library = $self->{library};
  $metadata->set_library($library);
  $metadata->set('book', $self);
  $library->add_metadata($metadata);
} # end subroutine add_metadata definition
########################################################################

=head2 get_metadata

Returns the metadata object or the value for a given key.

  $book->get_metadata;

This second form is actually equivalent to
$book->get_metadata->get($key) and should maybe just be dropped.

  $book->get_metadata($key);

=cut

sub get_metadata {
  my $self = shift;
  exists $self->{metadata} or die "metadata doesn't exist";
  @_ or return $self->{metadata};
  my ($key) = @_;

  # return the value for the given key
  my $metadata = $self->{metadata};
  $metadata->has_item($key) ||
    L->debug("key:'$key' doesn't exist in metadata");
  return $metadata->get($key);
} # end subroutine get_metadata definition
########################################################################

=head2 set_id

Can only happen once.

  $book->set_id($id);

=cut

sub set_id {
  my $self = shift;
  my ($id) = @_;
  defined($self->id) and croak("cannot change book id");
  $self->SUPER::set_id($id);
} # end subroutine set_id definition
########################################################################

=head1 Annotations

=begin developer

=head2 a bunch of methods

These all do the same thing, so they're in a foreach.  For extra speed
points, do eval $string on each one to save the runtime lookups on our
$blah_foo variables.

=end developer

=cut

########################################################################
# a pile of nearly identical methods for each annotation type
########################################################################
foreach my $foo (qw(note bookmark highlight selection)) {

  # pluralize
  my $foos = $foo . 's';
  # type map
  my $foo_type = {
    bookmark  => 'dtRdr::Bookmark',
    highlight => 'dtRdr::Highlight',
    note      => 'dtRdr::Note',
    selection => 'dtRdr::AnnoSelection',
  }->{$foo};
  $foo_type or die "ack $foo";

  my $persist = {
    'bookmark'  => 1,
    'highlight' => 1,
    'note'      => 1,
  }->{$foo};

  # and we'll need a getter
  my $get_foos = 'get_' . $foos;

  # methods we'll create and maybe call
  my $add_foo      = 'add_'     . $foo;
  my $delete_foo   = 'delete_'  . $foo;
  my $find_foo     = 'find_'    . $foo;
  my $node_foos    = 'node_'    . $foos;
  my $local_foos   = 'local_'   . $foos;
  my $related_foos = 'related_' . $foos;

=head2 add_<annotation>

  $book->add_note($node);
  $book->add_bookmark($node);
  $book->add_highlight($node);

=cut

my $add_foo_sub = sub {
  my $self = shift;
  my ($anno) = @_;
  eval { $anno->isa($foo_type) } or
    croak("Not a $foo");

  my $node_id = $anno->node->id;

  # memorize it
  my $data = $self->$get_foos;
  $data->{$node_id} ||= {};
  $data->{$node_id}{$anno->id} = $anno;
  #WARN "added $anno";

  # persist it
  $self->do_serialize('insert', $anno) if($persist);
}; # end subroutine $add_foo_sub definition
########################################################################

=head2 delete_<annotation>

  $book->delete_note($node);
  $book->delete_bookmark($node);
  $book->delete_highlight($node);

=cut

my $delete_foo_sub = sub {
  my $self = shift;
  my ($anno) = @_;
  eval { $anno->isa($foo_type) } or
    croak("Not a $foo");

  # all data
  my $data = $self->$get_foos;
  # node data
  my $node_data = $data->{$anno->node->id};
  $node_data or return();
  delete($node_data->{$anno->id});

  # persist it
  $self->do_serialize('delete', $anno) if($persist);
}; # end subroutine $delete_foo_sub definition
########################################################################

=head2 find_<annotation>

  my $note      = $book->find_note($anno_id);
  my $bookmark  = $book->find_bookmark($anno_id);
  my $highlight = $book->find_highlight($anno_id);

=cut

my $find_foo_sub = sub {
  my $self = shift;
  my ($anno_id) = @_;

  my $data = $self->$get_foos;
  foreach my $key (%$data) {
    if(my $anno = $data->{$key}{$anno_id}) {
      return($anno);
    }
  }
  return();
}; # end subroutine $find_foo_sub definition
########################################################################

=head2 node_<annotation>s

Get all highlights for a given node, including ancestors, those that
start in older siblings, etc.

  my @notes      = $book->node_notes($node);
  my @bookmarks  = $book->node_bookmarks($node);
  my @highlights = $book->node_highlights($node);

=cut

my $node_foos_sub = sub {
  my $self = shift;
  my ($node) = @_;
  $node or croak("must have a node");

  my @local = $self->$local_foos($node);

  # check the ancestor/descendant tree and pre-calculate local RP's
  my @others = $self->$related_foos($node);
  # @others and warn "my others is @others";

  # NOTE not worth sorting here, since we have to build a @todo list
  # that is just a group of positions, -- i.e.  overlapping highlights
  # don't sort start-before-start

  return(@local, @others);
}; # end subroutine $node_foos_sub definition
########################################################################

=head2 local_<annotation>s

Highlights which structurally belong to the given TOC node.

  my @notes      = $book->local_notes($node);
  my @bookmarks  = $book->local_bookmarks($node);
  my @highlights = $book->local_highlights($node);

=cut

my $local_foos_sub = sub {
  my $self = shift;
  my ($node) = @_;
  my $foo_ref = $self->$get_foos;
  #WARN($foo_ref ? (%{$foo_ref}) : 'none', " ($foo) for node id:",$node->id);
  return(values(%{ $foo_ref->{$node->id} || {} }));
}; # end subroutine $local_foos_sub definition
########################################################################

=head2 related_<annotation>s

Highlights which appear in the given TOC $node (e.g. anchored in
that node's descendants, ancestors, and older siblings.)

  my @notes      = $book->related_notes($node);
  my @bookmarks  = $book->related_bookmarks($node);
  my @highlights = $book->related_highlights($node);

=cut

my $related_foos_sub = sub {
  my $self = shift;
  my ($node) = @_;

  my @related =
    map({$self->$local_foos($_)}
      $self->descendant_nodes($node),
      $self->ancestor_nodes($node),
    );
  # @related and warn "\nrelated:  @related";
  # @related and warn "first is ", $related[0]->node->id;
  return(map({$self->localize_annotation($_, $node)} @related));
}; # end subroutine $related_foos_sub definition
########################################################################

my $package = __PACKAGE__;
{ # now just install them
  no strict 'refs';
  *{$package . '::' . $add_foo}      = $add_foo_sub;
  *{$package . '::' . $delete_foo}   = $delete_foo_sub;
  *{$package . '::' . $find_foo}     = $find_foo_sub;
  *{$package . '::' . $node_foos}    = $node_foos_sub;
  *{$package . '::' . $local_foos}   = $local_foos_sub;
  *{$package . '::' . $related_foos} = $related_foos_sub;
}
} # end pile of nearly identical methods
########################################################################
########################################################################

=head2 drop_selections

  $book->drop_selections;

=cut

sub drop_selections {
  my $self = shift;
  $self->{selections} = {};
} # end subroutine drop_selections definition
########################################################################

=head1 Position Juggling

=head2 _GP_to_NP

Globalize a Node Position

  $self->_GP_to_NP($node, $pos);

=cut

sub _GP_to_NP {
  my $self = shift;
  my ($node, $gp) = @_;
  my $np = $gp - $node->word_start;
  return($np);
} # end subroutine _GP_to_NP definition
########################################################################

=head2 _NP_to_GP

  $self->_NP_to_GP($node, $pos);

=cut

sub _NP_to_GP {
  my $self = shift;
  my ($node, $np) = @_;
  my $gp = $np + $node->word_start;
  return($gp);
} # end subroutine _NP_to_GP definition
########################################################################

=head2 localize_annotation

  $book->localize_annotation($anno, $node);

=cut

sub localize_annotation {
  my $self = shift;
  my ($anno, $node) = @_;
  my $dbg = 0;
  $dbg and warn "try to localize ", $anno->node->id;


  # TODO make this a proper method
  # also, what to do for out-of-range?
  my $localize = sub {
    my ($snode, $dnode, $s_rp) = @_;
    my $s_np = $self->_RP_to_NP($snode, $s_rp);
    my $gp = $self->_NP_to_GP($snode, $s_np);
    my $d_np = $self->_GP_to_NP($dnode, $gp);
    # out-of-range?
    my $d_rp = $self->_NP_to_RP($dnode, $d_np);
    $dbg and warn join("\n  ", 'details',
                  "source_rp: $s_rp",
                  "source_np: $s_np",
                  "gp:        $gp",
                  "dest_np:   $d_np",
                  "dest_rp:   $d_rp",
                  ), "\n  ";
    return($d_rp);
  };
  if($anno->isa('dtRdr::Range')) {

    my ($s_rp, $e_rp) = map({
      my $method = 'get_' . $_ . '_pos'; # play nice with Boundless
      my $sloc = $anno->$method;
      defined($sloc) or die "no offset";
      $localize->($anno->node, $node, $sloc);
    } qw(start end));

    my $nlength =
      $self->_NP_to_RP($node, $node->word_end - $node->word_start);

    if(($s_rp < 0) and ($e_rp > $nlength)) { # it spans it
      $s_rp = 0;
      $e_rp = $nlength;
    }
    else {
      # does it even touch the $node?
      return if(
        (($s_rp < 0) and ($e_rp < 0)) or
        (($s_rp > $nlength) and ($e_rp > $nlength))
        );
    }
    0 and warn "ok -- got this far";

    # otherwise, adjust min/max values
    ($s_rp < 0)        and ($s_rp = 0);
    ($e_rp > $nlength) and ($e_rp = $nlength);

    my $local = $anno->renode($node, range => [$s_rp, $e_rp]);
    return($local);
  }
  else {
    die "dunno how to do that yet jim";
  }
} # end subroutine localize_annotation definition
########################################################################

=head1 Annotation Serialization

=head2 get_anno_io

Get the annotation IO object.

=head2 set_anno_io

Set the annotation IO object.

=head2 do_serialize

This sidesteps the issue of having distinct add_foo(), add_foo_nowrite()
methods.  If there is a serializer (see L<dtRdr::Annotation::IO>)
available, we call $action on it with $object and %args.

  $book->do_serialize($action, $object, %args);

=cut

sub do_serialize {
  my $self = shift;
  my ($action, $object, %args) = @_;

  # can't serialize without one
  my $io = $self->anno_io or return;
  $io->can($action) or
    croak("incompetent? (cannot '$action') IO object: $io");

  $io->$action($object, %args);
} # end subroutine do_serialize definition
########################################################################


=head1 Text Search

=begin developer

=head2 how searching for positions and inserting annotations work

The search is performed as if:

  * All XML tags have been stripped from the book.
  * Any number of whitespace characters are one space.

The annotation offset values are then stored according to this convention.

When we do C<insert_nbh()>, we have to count our way through the content
in the character handler, while placing the following items:

  * spans (with classes according to the highlight ID) for highlights
  * href+img tags for bookmarks and notes

Notes will be viewed in a separate window/slice of frame.

=end developer

=head2 insert_nbh

Insert the note, bookmark, and highlight data for the given node.

  $content = $self->insert_nbh($node, $content);

This also creates the C<cache_chars> data needed for C<locate_string()>
operations.

=cut

{
########################################################################
# this closure could be almost eliminated with a private method
########################################################################
my $get_handlers = sub {
  my $self = shift;
  (@_ % 2) and croak("odd number of elements");
  my (%args) = @_;

$args{todo} or die "ack";
my @todo = @{$args{todo}};

$args{node} or die "ack";
my $node = $args{node};

my $output = '';
my $offset = 0;
my $chars = '';
# TODO open_hl, et al are not just highlights anymore
my %open_hl; # {$obj => ...} ?
my @hl_order;

my $mk_marker = sub { # XXX is this the best place?
  my ($anno) = @_;
  # transforms package name into css class
  # XXX is this the best way?
  my $type = lc(ref($anno));
  # e.g. 'dtRdr::Highlight' => dr_highlight
  $type =~ s/^\w*::/dr_/;
  $type =~ s/::/_/g;
  return(qq(<span class="$type ) . $anno->id . '">');
};

# If the open highlight is not the one that's ending, then the open one
# has to tag-hop the ending one.  (TODO optimize for nested case?)
my $hoppers = sub {
  # close all open tags, and reopen
  # XXX this is quite naive
  my $before = '';
  my $after = '';
  foreach my $hl (@hl_order) {
    $before .= '</span>';
    $after  .= $mk_marker->($hl);
  }
  return($before, $after);
}; # end $hoppers
########################################################################

my $splice_nbh  = sub {
  my ($rec_string, $new_offset) = @_;

  my $splicer = dtRdr::String::Splicer->new($rec_string);
  while(@todo) {

    # NOTE we want to get in after a tag at the start and before it at
    # the end -- this allows <p><highlight>foo</highlight></p> to DTRT
    # XXX but does break links when they get bookmarked :-/

    if(
      ($todo[0][1]->a == $todo[0][0])
      ? ($todo[0][0] < $new_offset)  # start
      : ($todo[0][0] <= $new_offset) # end
      ) {
      ($offset <= $todo[0][0]) or
        die "$offset <= $todo[0][0] < $new_offset failure";
      0 and WARN("handle $todo[0][0] after $offset and before $new_offset");
      my $marker;

      my $item = shift(@todo);
      my $target = $item->[0] - $offset;
      my $anno = $item->[1];
      if($anno->isa('dtRdr::Annotation::Range')) {
        if(exists($open_hl{$anno})) { # closing
          # get rid of it
          @hl_order = grep({$_ ne $anno} @hl_order);
          # and rebuild the index:
          %open_hl = map({$hl_order[$_] => $_} 0..$#hl_order);

          # now get the hopper bits and make a marker
          my ($before, $after) = $hoppers->();
          $marker = $before . '</span>' . $after;

          # notes here
          if($anno->isa('dtRdr::Note')) {
            # TODO document the note href convention
            $marker .=
              '<a class="dr_note" ' .
              'name="' .  $anno->id .  '" ' .
              'href="' .
                URI->new('dr://LOCAL/' . $anno->id . '.drnt')->as_string .
              '">' .
              '<img class="dr_note" src="' .
              $self->callbacks->img_src_rewrite(
                $self->callbacks->core_link('dr_note_link.png'),
                $self
              ) .
              '" />' .
              '</a>' .
              '';
          }
        }
        else { # opening
          # The hoppers are not needed here iff we stick to only
          # inserting <span> elements (because closing span "a" is the
          # same as closing span "b".)

          # remember where it is and in what order
          $open_hl{$anno} = push(@hl_order, $anno) -1;

          $marker = '';

          # bookmarks here
          if($anno->isa('dtRdr::Bookmark')) {
            $marker .=
              '<a class="dr_bookmark" ' .
              'name="' .  $anno->id .  '" ' .
              'href="' .
              URI->new('dr://LOCAL/' . $anno->id . '.drbm')->as_string .
              '">' .
              '<img class="dr_bookmark" src="' .
              $self->callbacks->img_src_rewrite(
                $self->callbacks->core_link('dr_bookmark_link.png'),
                $self
              ) .
              '" />' .
              '</a>' .
              '';
          }
          elsif($anno->isa('dtRdr::Highlight')) {
            # anchor for highlights
            $marker .= '<a class="dr_highlight" ' .
              'name="' .  $anno->id .  '"></a>';
          }
          elsif($anno->isa('dtRdr::AnnoSelection')) {
            # anchor for finds
            $marker .= '<a class="dr_selection" ' .
              'name="' .  $anno->id .  '"></a>';
          }

          # simple marker
          $marker .= $mk_marker->($anno);

        }
      } # end range-ish types
      else {
        # some new kind of annotation
        die "ouch, what's a $anno?";
      }
      $splicer->insert($target, $marker);
    } # end if we-should-do-something
    else {
      last;
    }
  }
  return($splicer->string);
}; # end sub $splice_nbh
########################################################################

# THE PARSER SUBS

my $flusher;
my $sh = sub {
  my ($p, $el, %atts) = @_;

  $flusher->();
  # TODO some way to not hop if tag pair is fully contained? (Twig!)
  # tag-hopping for the highlight spans
  my ($before, $after) = ('','');
  if(@hl_order) {
    ($before, $after) = $hoppers->();
  }

  my $rec_string = $p->recognized_string;

  # running callbacks
  # TODO some way to disable this if we don't need it?
  if($el eq 'img') {
    if(my ($s, $src, $e) = $rec_string =~ m/(.*src=")([^"]+)(.*)/) {
      $src = $self->callbacks->img_src_rewrite($src, $self);
      $rec_string = $s . $src . $e;
    }
    else {
      warn "oops $rec_string bit me";
    }
  }
  elsif($el eq 'pkg:outlineMarker') { # XXX needs to be book agnostic
    my $toc = $node->get_by_id($atts{id});
    $toc or die "cannot find a toc for this subnode";
    if($toc->copy_ok) {
      my $copy_link =
        '<a class="dr_copy" ' .
        'href="' .
          URI->new('dr://LOCAL/'. $toc->id . '.copy')->as_string .
        '">' .
        '<img class="dr_copy" src="' .
          $self->callbacks->img_src_rewrite(
            $self->callbacks->core_link('dr_copy_link.png'),
            $self
          ) .
        '" /></a>';
      $after .= $copy_link;
    }
  }

  $output .= $before . $rec_string . $after;
}; # end sh

my $eh = sub {
  my ($p, $el, %atts) = @_;

  $flusher->();
  my ($before, $after) = ('','');
  if(@hl_order) {
    ($before, $after) = $hoppers->();
    # don't reopen at the end:
    ($el eq 'justincasewehavenoroot') and ($after = '');
    # NOTE that $before also properly closes everything that's open as
    # long as we always wrap with this funny fakeroot tag
  }
  $output .= $before . $p->recognized_string . $after;
}; # end eh

# because $ch could fire willy-nilly, it is a lot saner,  safer, and
# more efficient to just accumulate the strings between tags, then $eh
# and $sh fire a flusher that does everything else

# TODO this sanification means $flusher might be doing useless
# acrobatics, but we are lacking some test coverage ATM

# SPEED NOTE: this gets to 11000 on bsd ch 16
my $called_char_handler_count = 0;

my $accum_string = '';
my $ch = sub {
  my ($p, $string) = @_;
  $accum_string .= $string;
  ## print STDERR length($string), " chars\n";
  $called_char_handler_count++;
}; # end ch

$flusher = sub {
  my $rec_string = $accum_string;
  $accum_string = '';
  $rec_string =~ s/&/&amp;/g;
  $rec_string =~ s/</&lt;/g;

  my $word_chars = $rec_string;
  # for counting, we say all groups of whitespace are one unit
  # but crossing tags messes with us a little
  my $lead = '';
  unless($chars) { # the very beginning
    # we don't count leading node whitespace if it is in a node before us
    if((! $node->is_root) and $self->whitespace_before($node)) {
      $word_chars =~ s/^\s+//;
      if($rec_string =~ s/^(\s+)//s) {
        $lead = $1;
      }
    }
    else {
      # AFAICT, this only happens on completely contrived books
      0 and warn "\n\nGAH! no whitespace before ", $node->id, "???!\n\n";
    }
  }
  elsif(substr($chars, -1) eq ' ') { # TO_OPT is m/ $/ faster?
    # strip leading space if the previous chars had a trailing space
    $word_chars =~ s/^\s+//;
    # honor this on the $rec_string too
    if($rec_string =~ s/^(\s+)//s) {
      $lead = $1;
    }
  }
  $word_chars =~ s/\s+/ /gs;
  $chars .= $word_chars;

  # get out early
  unless(length($word_chars)) {
    # but don't lose "\n"-only entries (breaks pre-formatted text)
    $output .= $lead . $rec_string;
    return;
  }

  my $new_offset = $offset + length($word_chars);

  # do placement within $rec_string, then put on $output
  my $spliced = '';
  $spliced = $splice_nbh->($rec_string, $new_offset)
    if(length($rec_string));

  $output .= $lead . $spliced;

  $offset = $new_offset;
  0 and warn "offset now $offset\n",
    (1 ? "spliced '$spliced'\n" : ' '),
    (1 ? "chars now '$chars'\n " : ' ');
}; # end flusher

my $done = sub {
  $self->cache_node_characters($node, $chars);

  #if(0) { # we have a mess with the parent thing again see is_nesty()
  #  @todo and warn "what's left: \n",
  #    join("\n", map({
  #      my $n = $_->[1]; $n . ' ' . $n->id . ' (' . $n->b . ')'
  #    } @todo)), "\n\n ";
  #  my $endpoint = $node->word_end;
  #  # XXX we'll never hit 359560 here!
  #  warn "end $endpoint with $offset and cache: ", length($chars), "\n";
  #  # try just lying to the splicer?
  #  $offset = $endpoint;
  #  warn 'splicing: ', $splice_nbh->('.....', $endpoint+1);
  #}

  L('speed')->debug(
    "called character handler $called_char_handler_count times"
  );

  DBG_DUMP('CACHE', 'cache', sub {$chars});

  return($output);
};

  return({
    handlers => {
      Start => $sh,
      End   => $eh,
      Char  => $ch,
    },
    done => $done
  });
}; # end sub $get_handlers
########################################################################
sub insert_nbh {
  my $self = shift;
  my ($node, $content) = @_;
  eval {$node->isa('dtRdr::TOC')} or
    croak('not a TOC object (usage: $book->insert_nbh($node, $str); )');

  RL('#speed')->info('running insert_nbh for ', $node->id);

  unless(@_ >= 2) { # get the content
    croak("must have content");
    die "this part isn't done";
    # TODO requires get_content() refactor
    # maybe something like _get_basic_content() ?
    # or just say YAGNI, bah, etc.
  }

  # The node_foos() calls give offsets in local coordinates.
  # The todo list is a list of arrays -- we'll shift it down to nothing.
  # First value of each is the position, second is the object.
  my @todo = (
    map({ [ $_->start_pos, $_ ], [ $_->end_pos, $_ ], }
      $self->node_highlights($node),
      $self->node_notes($node),
      $self->node_bookmarks($node),
      $self->node_selections($node),
    ),
  );
  #WARN "todo is ", join("|", map({$_->[1]} @todo));

  # we have to sort it here to get overlapping highlights to work
  @todo = sort({$a->[0] <=> $b->[0]} @todo);


  ######################################################################
  # some seemingly odd subref juggling here.  Don't worry.

  # get the handlers
  my $data = $get_handlers->($self, todo => \@todo, node => $node);

  my $parser = XML::Parser::Expat->new(ProtocolEncoding => 'UTF-8');
  $parser->setHandlers(%{$data->{handlers}});

  # XXX eek, what does this do to us?
  my $root = 'justincasewehavenoroot';

  # these appear to make no difference
  $content =~ s/^(\s*)//;
  my $leading_ws = $1 || '';
  $content =~ s/(\s*)$//;
  my $trailing_ws = $1 || '';

  eval { $parser->parse("<$root>$content</$root>") };
  if($@) {
    DBG_DUMP('PARSE', 'thecontentin.xml', sub{$content});
    die "XML parsing failed $@ ";
  }

  # finish
  my $output = $data->{done}->();

  $output =~ s/^<$root>// or die 'cannot get rid of my fake start tag';
  $output =~ s/<\/$root>$// or
    die 'cannot get rid of my fake end tag >>>' ,
      substr($output, -100) ,'<<<';

  # put the whitespace back
  $output = $leading_ws . $output . $trailing_ws;
  ######################################################################
  DBG_DUMP('INSERT', 'thecontent.xml', sub {$output});

  RL('#speed')->info('insert_nbh done');

  return($output);
} # end subroutine insert_nbh definition
} # and the closure
########################################################################

=head2 locate_string

Finds $string in $node and returns a Selection object (possibly for a
different node) with RENDERED POSITIONS.

  my $range = $book->locate_string($node, $string, $lwing, $rwing);

=cut

sub locate_string {
  my $self = shift;
  my ($node, $str, $lstr, $rstr) = @_;

  ######################################################################
  my $cache = $self->get_cache_chars($node);

  my ($s, $l, $r) = ($str, $lstr, $rstr);

  ######################################################################
  # NOTE:
  #   xml allows &lt; &gt; &amp; &quot; &apos
  #   all twig passes is &lt; and &amp; -- all else gets encoded
  # so, the assumption is that there is no &quot; etc in the node_chars

  s/&/&amp;/gs for($s,$l,$r);
  s/</&lt;/gs for($s,$l,$r);
  ######################################################################

  # a bit of fixup
  $_ =~ s/\s+/ /gs for($s, $l, $r);   # singularize whitespace
  $_ =~ s/^ $//s for($l, $r);         # null wings are an issue
  $s =~ s/^ // if($l =~ m/ $/);       # migrate leading space
  # XXX should we be able to allow
  # trailing space on the selection
  # without a right-context? (which
  # only happens at end-of-node)
  $s =~ s/ $// if($r =~ m/^(?: |$)/); # migrate trailing space

  # no trailing/leading space in selection
  # XXX this is a forced migration (as opposed to the context-wins one above)
  if($s =~ s/ $//) { $r = ' ' . $r if($r ne ''); }
  if($s =~ s/^ //) { $l = $l . ' ' if($l ne ''); }

  DBG_DUMP('CACHE', 'cache', sub {$cache});

  # the search:
  # my $pos = index($cache, "$l$s$r");
  # # TODO check that this was unique?

  # DBG_DUMP('CACHE', 'dump', sub {"$l$s$r\n$cache\n\n# vim\:nowrap"});

  # unless($pos >= 0) { # XXX this if() won't fit the m// approach
  #   # XXX some problem with getting utf8 in the selection when we had
  #   # given it an html-escaped character
  #   DBG_DUMP('SEARCH', 'bah',
  #     sub {"search failed on\r$l$s$r\r$cache\r\r# vim:nowrap"}
  #   );
  #   L->error(
  #     "could not find >>>$l$s$r<<<" .
  #     (0 ? " in >>>$cache<<<" : '') .
  #     "(pos $pos)"
  #   );
  #   # TODO try a little harder:
  #   # 1.  search for just $string, $lwing, or $rwing?
  #   # 2.  0,1,2,... and -1,-2,-3,... word search?
  #   return();
  # }

  # 0 and WARN("\n\nindex found ",
  #   join(", ", map({length($_)} $l, $s, $r, $cache)), "|",
  #   join(", ",
  #     $pos, $pos+length($l),
  #     $pos+length($l.$s), $pos+length($l.$s.$r)
  #   ));

  # my @len = map({length($_)} $l, $s, $r);
  # my ($spos, $epos) = (
  #   $pos + $len[0],
  #   $pos + $len[0] + $len[1]
  #   );
  # ######################################################################

  my @matches = _context_match(\$cache, $l, $s, $r);
  unless(@matches) {
    L->warn("no matches");
    return();
  }
  # XXX "too many" is an error, but we need to leave it as non-fatal at
  # least to accomodate the (currently) incompetent widgets
  (@matches > 1) and L->warn("too many matches");
  my ($spos, $epos) = @{$matches[0]};

  # adjust $node for tightness
  my $range = $self->reduce_word_scope($node, $spos, $epos);

  # turn into a selection
  my $selection = dtRdr::Selection->claim($range);

  # set the selected text property on it
  $selection->set_selected(substr($cache, $spos, $epos - $spos));

  # and a context based on the reduced-scope node
  # TODO oops, that's going to require some math here to avoid calling
  # get_content on that node :-/
  # $selection->set_context([$left,$right]);

  return($selection);
} # end subroutine locate_string definition
########################################################################

=head2 _context_match

  my @matches = _context_match(\$string, $left, $search, $right);

Returns a list of match pairs:  @matches = ([$start, $end], ...);

=cut

sub _context_match {
  my ($str, $li, $si, $ri) = @_;
  if(my $ref = ref($str)) {
    ($ref eq 'SCALAR') or croak("reference, but not a scalar ($ref)");
  }
  else { # I guess make a copy
    my $var = $str;
    $str = \$var;
  }

  my ($l, $s, $r) = ($li, $si, $ri);

  # prep them
  foreach my $v ($l, $s, $r) {
    $v =~ s/\s//g;
    L('search')->debug("now $v\n");
    $v = join('\\s*', map({s/([^a-zA-Z0-9_-])/\\$1/; $_} split(//, $v)));
    L('search')->debug("done $v\n");
  }
  L('search')->debug("search $l|$s|$r\n");

  my @starts;
  my @ends;
  while($$str =~ m/($l)\s*($s)\s*($r)/g) {
    my @s = @LAST_MATCH_START;
    my @e = @LAST_MATCH_END;
    # we need to shift() each of these since the first will be the
    # entire match
    shift(@s);
    shift(@e);
    (@$_ == 3) or die for(\@s, \@e);
    L('search')->debug("found ", join("|", map({join(",", @$_)} \@s, \@e)));
    push(@starts, $s[1]);
    push(@ends,   $e[1]);
  }
  @starts or return();
  (@starts == @ends) or die "something went wrong there @starts @ends";
  my @matches = map({[$starts[$_], $ends[$_]]} 0..$#starts);
  L('search')->debug(scalar(@matches), " matches");
  return(@matches);
} # end subroutine _context_match definition
########################################################################

=head2 reduce_word_scope

Returns a Range with the appropriate TOC node and start/end positions.

  my $range = $book->reduce_word_scope($node, $start, $end);

=cut

sub reduce_word_scope {
  my $self = shift;
  my ($node, $spos, $epos) = @_;

  my ($s,$e) = ($spos, $epos);
  my $nstart = $node->word_start;
  $_ += $nstart for($s,$e);

  my $found;
  foreach my $d (reverse($node->descendants)) {
    # other book classes need to deal with black holes
    defined($d->word_start) or
      die $d->id, " node did not get an aot entry!";
    if(($d->word_start <= $s) and ($d->word_end >= $e)) {
      $found = $d;
      last;
    }
  }
  if($found) {
    # now adjust $spos, $epos correctly
    my $delta = $found->word_start - $node->word_start; # not correct
    $spos = $spos - $delta;
    $epos = $epos - $delta;
  }
  else {
    # positions are golden
    $found = $node;
  }

  return(dtRdr::Range->create(node => $found, range => [$spos, $epos]));
} # end subroutine reduce_word_scope definition
########################################################################

=head2 has_cached_node_characters

  my $bool = $book->has_cached_node_characters($node);

=cut

sub has_cached_node_characters {
  my $self = shift;
  my ($node) = @_;

  return(exists($self->{cache_chars}{$node->id}));
} # end subroutine has_cached_node_characters definition
########################################################################

=head2 cache_node_characters

Saves the characters in the cache, and will eventually implement cache
management.

  $book->cache_node_characters($node, $chars);

=cut

sub cache_node_characters {
  my $self = shift;
  my ($node, $chars) = @_;
  eval {$node->isa('dtRdr::TOC')} or Carp::confess('not a TOC object');

  # XXX this caching mechanism will turn into a memory leak => do
  # something like close_book() or else have it be a short
  # (maybe three-element) array.
  $self->{cache_chars}{$node->id} = $chars;
} # end subroutine cache_node_characters definition
########################################################################

=head2 get_cache_chars

Get the cache characters for a given TOC node.

  my $chars = $book->get_cache_chars($node);

=cut

sub get_cache_chars {
  my $self = shift;
  my ($toc) = @_;
  eval {$toc->isa('dtRdr::TOC')} or
    croak('not a TOC object (usage: $book->get_cache_chars($node);)');

  my $id = $toc->id;

  # you should only call this if you know they are there
  croak("no cache for node:'$id'")
    unless($self->has_cached_node_characters($toc));

  return($self->{cache_chars}{$id});
} # end subroutine get_cache_chars definition
########################################################################

=head2 get_node_characters

Get the characters for $node.  Will check the cache and/or create them.

  my $chars = $book->get_node_characters($node);

=cut

sub get_node_characters {
  my $self = shift;
  my ($node) = @_;

  if($self->has_cached_node_characters($node)) {
    return($self->get_cache_chars($node));
  }
  else {
    my $chars = $self->create_node_characters($node);
    $self->cache_node_characters($node, $chars);
    return($chars);
  }
} # end subroutine get_node_characters definition
########################################################################

=head2 create_node_characters

  my $chars = $book->create_node_characters($node);

=cut

sub create_node_characters {
  my $self = shift;
  my ($node) = @_;

  my $content = $self->get_trimmed_content($node);
  $content or die("got no content for node: ", $node->id);

  my $chars;
  if(0) { # these are not the slow droids you're looking for
    my $twig = XML::Twig->new( keep_spaces => 1 );
    eval { $twig->parse($content); };
    $@ and die("parse failed: '$@'");
    $chars = $twig->root->text;
    # make it align with our typical cache
    $chars =~ s/&/&amp;/g;
    $chars =~ s/</&lt;/g;
  }
  else { # this is slightly faster, but maybe still not correct
    $chars = $content;
    $chars =~ s/<[^>]+>//g;
    require HTML::Entities;
    $chars = HTML::Entities::decode_entities($chars);
    if(0) { utf8::upgrade($chars); }
    else { $chars =~ s/[\xA0\x{85}\x{2028}\x{2029}]+/ /g; }
    $chars =~ s/&/&amp;/g;
    $chars =~ s/</&lt;/g;
  }
  if((not $node->is_root) and $self->whitespace_before($node)) {
    $chars =~ s/^\s+//;
  }
  $chars =~ s/\s+/ /g;
  return($chars);
} # end subroutine create_node_characters definition
########################################################################

=head1 TOC-related Methods

=head2 get_toc

Every book has a table of contents.

  my $root = $book->get_toc;

See TOC for tree-related methods and below for book-related methods
(book related methods can transcend the tree structure, allowing us to
support less-than-elegant book formats.)

=cut

# plain accessor

=head2 find_toc

Find the TOC node for $id.

  my $toc = $book->find_toc($id);

=cut

sub find_toc {
  my $self = shift;
  my ($id) = @_;
  return($self->toc->get_by_id($id));
} # end subroutine find_toc definition
########################################################################

=head2 descendant_nodes

  my @nodes =  $book->descendant_nodes($node);

=cut

sub descendant_nodes {
  my $self = shift;
  my ($node) = @_;
  return($node->descendants);
} # end subroutine descendant_nodes definition
########################################################################

=head2 ancestor_nodes

  my @nodes =  $book->ancestor_nodes($node);

=cut

sub ancestor_nodes {
  my $self = shift;
  my ($node) = @_;
  return($node->ancestors);
} # end subroutine ancestor_nodes definition
########################################################################

=head2 visible_nodes

  my @visible = $book->visible_nodes;

=cut

sub visible_nodes {
  my $self = shift;

  my $toc = $self->toc or croak('no toc');

  my @vis;
  $toc->rmap(sub { my ($n) = @_;
    $n->visible and push(@vis, $n);
  });
  return(@vis);
} # end subroutine visible_nodes definition
########################################################################

=head1 See Also

L<dtRdr::Plugins::Book>

=cut

=head1 AUTHOR

Eric Wilhelm <ewilhelm at cpan dot org>

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

1;
# vim:ts=2:sw=2:et:sta
