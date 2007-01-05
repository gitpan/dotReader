package dtRdr::Book74;

use warnings;
use strict;

use dtRdr::Logger;

# extracted from r74 for benchmark purposes

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

\&insert_nbh;
