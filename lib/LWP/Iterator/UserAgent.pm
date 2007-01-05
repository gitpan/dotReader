package LWP::Iterator::UserAgent;
$VERSION = eval{require version}?version::qv($_):$_ for(0.0.1);

use warnings;
use strict;
use Carp;

use base 'LWP::Parallel::UserAgent';

use Time::HiRes;
use constant {DBG => 0};

=head1 NAME

LWP::Iterator::UserAgent - a non-blocking LWP iterator

=head1 SYNOPSIS

=cut

#sub on_failure { warn "we failed"; undef}
#sub on_connect { warn "we connected"; undef}
#sub on_return { warn "we returned"; undef}

=head2 new

  my $pua = LWP::Iterator::UserAgent->new(deadline => 10.5);

=cut

sub new {
  my $class = shift;
  my (%cnf) = @_;
  my $self = $class->SUPER::new(%cnf);
  $self->{deadline} = $cnf{deadline};
  return($self);
} # end subroutine new definition
########################################################################

=head2 deadline

  $pua->deadline;

  $pua->deadline($seconds);

=cut

sub deadline {
  my $self = shift;
  LWP::Debug::trace("($_[0])");
  $self->{deadline} = $_[0] if(@_);
  $self->{deadline};
} # end subroutine deadline definition
########################################################################

=head2 pester

Where the Parallel::UserAgent expects you to wait() on it, this class
needs to be nagged or it will never do anything.

  while(1) {
    $pua->pester and last;
  }

Optionally, you can pass a timeout value.

  $are_we_there_yet = $pua->pester(0.1);

Note that while the LWP::Parallel::UserAgent class uses timeout as an
overall deadline, this class uses the deadline attribute.

=cut

sub pester {
  my $self = shift;
  my ($timeout) = @_;

  defined($self->{deadline}) or die "must have a deadline";
  $timeout = $self->{'timeout'} unless defined $timeout;
  my $start_time = Time::HiRes::time;
  my $tick = sub {
    my $diff = Time::HiRes::time - $start_time;
    DBG and warn "deadline $self->{deadline} - $diff\n";
    $self->{deadline} -= $diff;
  };

  # shortcuts to in- and out-filehandles
  my $fh_out = $self->{'select_out'};
  my $fh_in  = $self->{'select_in'};

  $self->{_is_done} = 1 unless(
      scalar(keys(%{$self->{'current_connections'}}))  or
      scalar(
        $self->{'handle_in_order'} ?
        @{$self->{'ordpend_connections'}} :
        keys(%{$self->{'pending_connections'}})
      )
    );
  if($self->{_is_done}) {
    $self->_remove_all_sockets();
    DBG and warn "all done\n";
    return 1;
  }
  elsif(! $self->{_is_connected}) {
    DBG and warn "connect\n";
    $self->_make_connections;
    $self->{_is_connected} = 1;
    DBG and warn "connected\n";
    # deadline?
    $tick->();
    return 0; # maybe puts us a little over the deadline, but no biggie
  }
  elsif((scalar $fh_in->handles) or (scalar $fh_out->handles)) {
    LWP::Debug::debug("Selecting Sockets, timeout is $timeout seconds");
    if(my @ready = IO::Select->select($fh_in, $fh_out, undef, $timeout)) {
      DBG and warn "ready!\n";
      # something is ready for reading or writing
      my ($ready_read, $ready_write, $error) = @ready;

      # WRITE QUEUE
      foreach my $socket (@$ready_write) {
        my $so_err;
        if($socket->can('getsockopt')) { # we also might have IO::File!
          # check if there is any error
          $so_err = $socket->getsockopt( Socket::SOL_SOCKET(),
                                         Socket::SO_ERROR() );
          LWP::Debug::debug( "SO_ERROR: $so_err" ) if $so_err;
        }
        $self->_perform_write($socket, $timeout) unless $so_err;
      }

      # READ QUEUE
      $self->_perform_read($_, $timeout) for(@$ready_read);
      return(0);
    }
    else {
      # empty array, means that select timed out
      DBG and warn "timeout\n"; # ELW: not really a timeout here
      LWP::Debug::trace('select timeout');
      return if($tick->() > 0); # XXX hack?
      # set all active requests to "timed out"
      foreach my $socket ($fh_in->handles ,$fh_out->handles) {
        my $entry = $self->{'entries_by_sockets'}->{$socket};
        delete $self->{'entries_by_sockets'}->{$socket};
        unless($entry->response->code) {
          # each entry gets its own response object
          my $response = HTTP::Response->new(&HTTP::Status::RC_REQUEST_TIMEOUT,
                                           'User-agent timeout (select)');
          $entry->response($response);
          $response->request($entry->request);
          $self->on_failure($entry->request, $response, $entry);
        }
        else {
          my $res = $entry->response;
          $res->message($res->message . " (timeout)");
          $entry->response ($res);
          # XXX on_failure for now, unless on_return is better
          $self->on_failure($entry->request, $res, $entry);
        }
        $self->_remove_current_connection($entry);
      } # end foreach socket
      # and delete from read- and write-queues
      $fh_out->remove($_) for($fh_out->handles);
      $fh_in->remove($_)  for($fh_in->handles);
      # TODO continue processing -- pending requests might still work?
      #      except if we got here, we are past the deadline
      return(1);
    } # end if (@ready...) {} else {}
  }
  die "clueless";
} # end subroutine pester definition
########################################################################

=head1 AUTHOR

Eric Wilhelm (@) <ewilhelm at cpan dot org>

http://scratchcomputing.com/

=head1 COPYRIGHT

Copyright (C) 2006 Eric L. Wilhelm and OSoft, All Rights Reserved.

Portions derived from LWP::Parallel::UserAgent, copyright 1997-2004 Marc
Langheinrich.

=head1 NO WARRANTY

Absolutely, positively NO WARRANTY, neither express or implied, is
offered with this software.  You use this software at your own risk.  In
case of loss, no person or entity owes you anything whatsoever.  You
have been warned.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# vi:ts=2:sw=2:et:sta
1;
