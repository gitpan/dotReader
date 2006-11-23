#!/usr/bin/perl

# call this as $0 <profile> <count>
# without a count, we're only verifying behavior

# this demonstrates a 20x-60x speed-up potential (where the gain is
# highly dependent on the book size due to the excessive number of calls
# to get_xml_content caused by on overly-recursive appending strategy

use warnings;
use strict;

use Benchmark qw(:all);

use lib 'lib';
use dtRdr::Book::ThoutBook_1_0;

my $want = 0;
@ARGV and ($want = shift(@ARGV));
my $bench = 0;
@ARGV and ($bench = shift(@ARGV));


my @profiles = (
  ['test_packages/FreeBSD_Developers_Handbook/FreeBSDDevelopersHandbook.xml',
    [qw(
      TOOLS
      X86
      ARCHITECTURES
      KERNEL
      IPC
    )]
  ],
  ['test_packages/perl/Perl-5.8.xml',
    [qw(
      lib_Pod_perlintro_html
      lib_Pod_perlembed_html
      lib_Pod_perlreftut_html
      lib_Pod_perldsc_html
      lib_XS_APItest_html
    )]
  ],
); 

# now pick a profile,
my $profile = $profiles[$want];

my $book = dtRdr::Book::ThoutBook_1_0->new;
$book->load_uri($profile->[0]);

# do the benchmark for each node in it
foreach my $node_id (@{$profile->[1]}) {
  my $node = $book->toc->get_by_id($node_id);
  my $length = $node->range->b - $node->range->a;
  my $ch_count = scalar($node->get_children);
  print "benching $node_id (~$length bytes with $ch_count children)\n";
  if(1) {
    my @plan = $book->_build_trim_plan($node);
    print scalar(@plan), " step plan\n";
  }
  my %tests = (
    A => sub {
      $book->get_trimmed_content1($node)
    },
    B => sub {
      $book->get_trimmed_content2($node)
    },
  );
  if($bench) {
    my $results = timethese($bench, \%tests); 
    cmpthese($results);
    print "\n";
  }
  else {
    # make sure to check the results of A against B
    my $answer = $tests{A}->();
    my $ok = ($answer eq $tests{B}->()) ? 'ok' : 'not ok';
    print "$ok\n";
  }
}

BEGIN {
  package dtRdr::Book::ThoutBook_1_0::Base;

# this is a straight drop of the original.  If we need to revisit this
# issue, keep both of these and add a sub to the benchmark plan which
# calls the core method.
sub get_trimmed_content1 {
  my $self = shift;
  my ($toc) = @_;

  # this does a properly tree-walking no-render and no-render-children
  # elimination for all of $toc's descendants -- thus eliminating the
  # need for parse_content() altogether

  my ($start, $end) = ($toc->range->a, $toc->range->b);
  my $xmlcontent = $self->get_xml_content or die;

  # SPEED NOTE A:  The recursive algorithm will be slower than the "get
  # all of your ducks in a row and do as few reads as possible"
  # approach, but only where there is a very large number of rendered
  # descendants (actually, 20 continuous reads+between bits is a lot of
  # substr calls and that seems somewhat typical.)  We could probably
  # use recursion to build the plan and still come out faster.
  # FreeBSD chapter 16 is a good example of a worst case
  0 and WARN "recurse ", $toc->id, " ($start, $end)";

  # SPEED NOTE B:  Seeking on a filehandle might be better.

  use bytes;

  my @children = $toc->get_children();
  unless(@children) { # terminal node
    return(substr($xmlcontent, $start, $end - $start));
  }

  my $f_start  = $children[0]->range->a;
  my $l_end    = $children[-1]->range->b;

  # just up to the first child
  my $content = substr($xmlcontent, $start, $f_start - $start);
  my $rc = $toc->get_info('render_children');
  for(my $i = 0; $i < @children; $i++) {
    my $child = $children[$i];
    if($rc) {
      if($child->get_info('render')) {
        $content .= $self->get_trimmed_content1($child);
      }
    }
    # AND we need to get any bit that might be between the children
    if(my $next = $children[$i+1]) {
      my $c_stop = $child->range->b;
      my $n_start = $next->range->a;
      if($c_stop < $n_start) {
        #Carp::cluck("child gap $i $c_stop $n_start");
        0 and WARN "betweeny ($c_stop, $n_start)";
        $content .= substr($xmlcontent, $c_stop, $n_start - $c_stop);
      }
      else { # just to assert
        ($c_stop == $n_start) or die "bad overlap $c_stop $n_start";
      }
    }
  }
  # and after the last child
  $content .= substr($xmlcontent, $l_end, $end - $l_end);

  return($content);
} # end subroutine get_trimmed_content1 definition
########################################################################
sub get_trimmed_content2 {
  my $self = shift;
  my ($toc) = @_;

  my @plan = $self->_build_trim_plan($toc);
  0 and warn "got plan ", join("\n  ", '',
    map({'[' . join(", ", @$_) . ']'} @plan)), "\n";
  my $xmlcontent = $self->get_xml_content or die;
  use bytes;

  my $content = '';
  foreach my $item (@plan) {
    my ($start, $stop) = @$item;
    $content .= substr($xmlcontent, $start, $stop - $start);
  }
  return($content);
} # end subroutine get_trimmed_content2 definition
########################################################################

=head2 _build_trim_plan

  @plan = $self->_build_trim_plan($node);

=cut

sub _build_trim_plan {
  my $self = shift;
  my ($toc, $plan) = @_;
  $plan ||= [];

  my ($start, $end) = ($toc->range->a, $toc->range->b);
  my @children = $toc->get_children();
  unless(@children) { # terminal node
    $self->_append_trim_plan($start, $end, $plan);
    return(@$plan);
  }

  my $f_start  = $children[0]->range->a;
  my $l_end    = $children[-1]->range->b;

  # just up to the first child
  $self->_append_trim_plan($start, $f_start, $plan);
  my $rc = $toc->get_info('render_children');
  for(my $i = 0; $i < @children; $i++) {
    my $child = $children[$i];
    if($rc) {
      if($child->get_info('render')) {
        $self->_build_trim_plan($child, $plan);
      }
    }
    # AND we need to get any bit that might be between the children
    if(my $next = $children[$i+1]) {
      my $c_stop = $child->range->b;
      my $n_start = $next->range->a;
      if($c_stop < $n_start) {
        $self->_append_trim_plan($c_stop, $n_start, $plan);
      }
      else { # just to assert
        ($c_stop == $n_start) or die "bad overlap $c_stop $n_start";
      }
    }
  }
  # and after the last child
  $self->_append_trim_plan($l_end, $end, $plan);
  return(@$plan);
} # end subroutine _build_trim_plan definition
########################################################################

=head2 _append_trim_plan

  $self->_append_trim_plan($start, $stop, \@plan);

=cut

sub _append_trim_plan {
  my $self = shift;
  my ($start, $stop, $plan) = @_;
  #warn "plan: $start, $stop";
  @$plan or return(@$plan = ([$start, $stop]));
  if($start == $plan->[-1][1]) {
    $plan->[-1][1] = $stop;
  }
  else {
    push(@$plan, [$start, $stop]);
  }
} # end subroutine _append_trim_plan definition
########################################################################

}

# vim:ts=2:sw=2:et:sta:nowrap
