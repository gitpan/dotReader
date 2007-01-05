package dtRdr::BookUtil::AnnoInsert;
$VERSION = eval{require version}?version::qv($_):$_ for(0.0.1);

use warnings;
use strict;

use dtRdr::Logger;

use Class::Accessor::Classy;
ro 'parser';
ro qw(
  book
  node
  todo
  open_annos
  anno_order
);
ro qw(
  output
  leading_ws
  trailing_ws
);
rw qw(
  chars
  offset
);
no  Class::Accessor::Classy;

our $ROOT = 'justincasewehavenoroot';


=head1 NAME

dtRdr::BookUtil::AnnoInsert - XML parse/populate

=head1 SYNOPSIS

  my $answer = dtRdr::BookUtil::AnnoInsert->new(
    $book, %params
    )->parse($string)->done;

=cut

=head1 Frontend

=head2 new

  my $ai = dtRdr::BookUtil::AnnoInsert->new($book, %params);

=cut

sub new {
  my $class = shift;
  my $book = shift;
  eval {$book->isa('dtRdr::Book')} or croak("not a book");
  (@_ % 2) and croak("odd number of elements in argument list");
  my %args = @_;
  $args{todo} or die "ack";
  $args{node} or die "ack";
  my $self = {%args, book => $book};
  my $parser = $self->{parser} = 
    XML::Parser::Expat->new(ProtocolEncoding => 'UTF-8');
  $self->{chars} = [];
  $self->{output} = []; # ridiculously faster as an array
  $self->{offset} = 0;
  $self->{trailing_space} = 0;
  $self->{anno_order} = [];
  $self->{open_annos} = {};

  $self->{accum_string} = '';
  $parser->setHandlers(
    Start => sub {$self->start_handler(@_)},
    End   => sub {$self->end_handler(@_)},
    Char  => sub {$self->{accum_string} .= $_[1]},
  );

  bless($self, $class);
  return($self);
} # end subroutine new definition
########################################################################


=head2 parse

  $ai->parse($string);

=cut

sub parse {
  my $self = shift;
  my ($string) = @_;

  # these appear to make no difference
  $string =~ s/^(\s*)//;
  $self->{leading_ws} = $1 || '';
  $string =~ s/(\s*)$//;
  $self->{trailing_ws} = $1 || '';

  eval { $self->parser->parse("<$ROOT>$string</$ROOT>") };
  if($@) {
    DBG_DUMP('PARSE', 'thestringin.xml', sub{$string});
    die "XML parsing failed $@ ";
  }
  return($self);
} # end subroutine parse definition
########################################################################

=head2 done

  $output = $ai->done;

=cut

sub done {
  my $self = shift;

  my $book = $self->book;
  my $node = $self->node;

  $book->cache_node_characters($node, join('', @{$self->chars}));

  DBG_DUMP('CACHE', 'cache', sub {join('', @{$self->chars})});

  my $output = $self->output;
  my $n = 0;
  $n++ until(length($output->[$n]));
  $output->[$n] =~ s/^<$ROOT>// or die 'cannot get rid of my fake start tag';
  $n = -1;
  $n-- until(length($output->[$n]));
  $output->[$n] =~ s/<\/$ROOT>$// or
    die 'cannot get rid of my fake end tag >>>' ,
      $output->[$n] ,'<<<';

  # put the whitespace back
  return(join('', $self->leading_ws, @$output, $self->trailing_ws));
} # end subroutine done definition
########################################################################

=head1 XML Parsing Guts

=head2 start_handler

  $ai->start_handler($p, $el, %atts);

=cut

sub start_handler {
  my $self = shift;
  my ($p, $el, %atts) = @_;

  $self->do_chars;
  # TODO some way to not hop if tag pair is fully contained?
  # tag-hopping for the highlight spans
  my ($before, $after) = ('','');
  if(@{$self->anno_order}) {
    ($before, $after) = $self->hoppers;
  }

  my $rec_string = $p->recognized_string;

  my $book = $self->book;
  my $node = $self->node;

  # running callbacks
  if(my $subref = $self->{xml_callbacks}{start}{$el}) {
    $subref->(
      $book,
      node       => $node,
      before     => \$before,
      after      => \$after,
      during     => \$rec_string,
      attributes => \%atts,
    );
  }

  push(@{$self->{output}}, $before, $rec_string, $after);
  return;
} # end subroutine start_handler definition
########################################################################

=head2 end_handler

  $ai->end_handler($p, $el);

=cut

sub end_handler {
  my $self = shift;
  my ($p, $el, %atts) = @_;

  $self->do_chars;
  my ($before, $after) = ('','');
  if(@{$self->anno_order}) {
    ($before, $after) = $self->hoppers;
    # don't reopen at the end:
    ($el eq $ROOT) and ($after = '');
    # NOTE that $before also properly closes everything that's open as
    # long as we always wrap with this funny fakeroot tag
  }
  push(@{$self->{output}}, $before, $p->recognized_string, $after);
  return;
} # end subroutine end_handler definition
########################################################################

=head2 do_chars

  $ai->do_chars($byte_offset);

=cut

sub do_chars {
  my $self = shift;

  # maybe nothing to do here
  length($self->{accum_string}) or return;

  my $rec_string = $self->{accum_string};
  $self->{accum_string} = '';

  # clean it up (wait, why is the parser giving us this?)
  $rec_string =~ s/&/&amp;/g;
  $rec_string =~ s/</&lt;/g;

  my $book = $self->book;
  my $node = $self->node;
  my $chars = $self->{chars};
  my $offset = $self->offset;

  my $word_chars = $rec_string;
  # for counting, we say all groups of whitespace are one unit
  # but crossing tags messes with us a little
  my $lead = '';
  unless(@$chars) { # the very beginning
    # we don't count leading node whitespace if it is in a node before us
    if((! $node->is_root) and $book->whitespace_before($node)) {
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
  elsif($self->{trailing_space}) {
    # strip leading space if the previous chars had a trailing space
    $word_chars =~ s/^\s+//;
    # honor this on the $rec_string too
    if($rec_string =~ s/^(\s+)//s) {
      $lead = $1;
    }
  }
  $word_chars =~ s/\s+/ /gs;

  # get out early
  unless(length($word_chars)) {
    # but don't lose "\n"-only entries (breaks pre-formatted text)
    push(@{$self->{output}}, $lead, $rec_string);
    return;
  }
  # NOTE: way faster (30-50%) to check against a short string and
  # remember it vs asking perl to look at the end of the very long and
  # ever-changing $$char string.
  $self->{trailing_space} = (substr($word_chars, -1) eq ' ');
  push(@$chars, $word_chars);

  my $new_offset = $offset + length($word_chars);

  # do placement within $rec_string, then put on output
  my $spliced = '';
  $spliced = $self->splice($rec_string, $new_offset)
    if(length($rec_string));

  push(@{$self->{output}}, $lead, $spliced);

  $offset = $new_offset;
  $self->set_offset($offset);
  0 and warn "offset now $offset\n",
    (1 ? "spliced '$spliced'\n" : ' '),
    (1 ? "chars now '@$chars'\n " : ' ');
} # end subroutine do_chars definition
########################################################################

=head1 String Handling

=head2 splice

  my $spliced = $ai->splice($string, $new_offset);

=cut

sub splice {
  my $self = shift;
  my ($rec_string, $new_offset) = @_;

  my $splicer = dtRdr::String::Splicer->new($rec_string);
  my $book = $self->book;
  my $todo = $self->todo;
  my $open_annos = $self->open_annos;
  my $anno_order = $self->anno_order;
  my $offset = $self->offset;

  while(@$todo) {

    # NOTE we want to get in after a tag at the start and before it at
    # the end -- this allows <p><highlight>foo</highlight></p> to DTRT
    # XXX but does break links when they get bookmarked :-/

    if(
      ($todo->[0][1]->a == $todo->[0][0])
      ? ($todo->[0][0] < $new_offset)  # start
      : ($todo->[0][0] <= $new_offset) # end
      ) {
      ($offset <= $todo->[0][0]) or
        die "$offset <= $todo->[0][0] < $new_offset failure";
      0 and WARN("handle $todo->[0][0] after $offset and before $new_offset");
      my $marker;

      my $item = shift(@$todo);
      my $target = $item->[0] - $offset;
      my $anno = $item->[1];
      if($anno->isa('dtRdr::Annotation::Range')) {
        if(exists($open_annos->{$anno})) { # closing
          # get rid of it
          @$anno_order = grep({$_ ne $anno} @$anno_order);
          # and rebuild the index:
          %$open_annos = map({$anno_order->[$_] => $_} 0..$#$anno_order);

          # now get the hopper bits and make a marker
          my ($before, $after) = $self->hoppers;
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
              # TODO cache this before starting the parse
              $book->get_callbacks->img_src_rewrite(
                $book->get_callbacks->core_link('dr_note_link.png'),
                $book
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
          $open_annos->{$anno} = push(@$anno_order, $anno) -1;

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
              # TODO cache this before starting the parse
              $book->get_callbacks->img_src_rewrite(
                $book->get_callbacks->core_link('dr_bookmark_link.png'),
                $book
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
          $marker .= $self->mk_marker($anno);

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
} # end subroutine splice definition
########################################################################

=head1 Formatting

=head2 hoppers

  $ai->hoppers;

=cut

sub hoppers {
  my $self = shift;
  my $before = '';
  my $after = '';
  foreach my $hl (@{$self->anno_order}) {
    $before .= '</span>';
    $after  .= $self->mk_marker($hl);
  }
  return($before, $after);
} # end subroutine hoppers definition
########################################################################

=head2 mk_marker

Create the start of a <span style="..." id="..."> marker

  my $marker = $self->mk_marker($annotation);

=cut

sub mk_marker {
  my $self = shift;
  my ($anno) = @_;
  # transforms package name into css class
  # XXX is this the best way?
  my $type = lc(ref($anno));
  # e.g. 'dtRdr::Highlight' => dr_highlight
  $type =~ s/^\w*::/dr_/;
  $type =~ s/::/_/g;
  return(qq(<span class="$type ) . $anno->id . '">');
} # end subroutine mk_marker definition
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
