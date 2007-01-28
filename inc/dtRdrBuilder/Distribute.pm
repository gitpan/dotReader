package inc::dtRdrBuilder::Distribute;

# Copyright (C) 2006, 2007 by Eric Wilhelm and OSoft, Inc.

# server-related stuff

use warnings;
use strict;
use Carp;

=head1 ACTIONS

=over

=cut

our $RUN_SSH = 1; # enables actual execution
our $VERBOSE = 1;

my $dosystem = sub {
  warn "# @_\n";
  $RUN_SSH and return(system(@_));
  return 0;
};

=item demo_push

OBSOLETE

Push and symlink binary_build/ to the server/directory specified in
server_details.yml

  server: example.com
  directory: foo
  distribute:
    - user@host:dir/

=cut

sub ACTION_demo_push {
  my $self = shift;

  my @args = @{$self->{args}{ARGV}};
  my $release = shift(@args);
  my %opts = $self->_my_args;
  $release = $opts{release} unless(defined($release));
  $release or die "must have release name";
  $release =~ m/ / and die;

  my $data = $self->server_details;
  my $server = $data->{server} or die;
  my $dir = $data->{directory} or die;
  $dir .= "/$^O" unless($^O eq 'MSWin32');

  $self->jailshell_ssh($server, "test '!' -e $dir/$release") or
    die "'$dir/$release' already exists";

  my $have_current = $self->jailshell_ssh($server,
    "test -e $dir/current &&" .
    "cp -RH $dir/current $dir/$release"
  );

  $self->ssh_rsync($server,
    '-rz', $self->binary_build_dir . '/', $dir . '/' . $release . '/'
  );

  unless($opts{nolink}) {
    $self->jailshell_ssh($server,
      "rm $dir/current && ln -s $release $dir/current"
    );
  }
} # end subroutine ACTION_demo_push definition
########################################################################

=item bindistribute

Distribute binary_build/ to each of the @distribute entries in the
server_details.yml file.

=cut

sub ACTION_bindistribute {
  my $self = shift;

  my $data = $self->server_details;
  if($data->{distribute}) {
    my @dirs = @{$data->{distribute}};
    foreach my $dest (@dirs) {
      $dest =~ s#/*$#/#;
      $dosystem->('rsync', '--delete', '-rv',
        $self->binary_build_dir . '/', $dest
      ) and die;
    }
  }
} # end subroutine ACTION_bindistribute definition
########################################################################

=item package_push

Push the packaged binary release for the current platform.

=cut

sub ACTION_package_push {
  my $self = shift;

  my $src = $self->distfilename;
  (-e $src) or die "no file $src";

  $self->transfer_and_link($src);
} # end subroutine ACTION_package_push definition
########################################################################

=item dist_push

Push the source tarball.

=cut

sub ACTION_dist_push {
  my $self = shift;

  my $src = $self->dist_dir . '.tar.gz';
  (-e $src) or die "no file $src";

  $self->transfer_and_link($src);
  $dosystem->('cpan-upload', "http://dotreader.com/downloads/$src") and
    die "cpan-upload failed";
} # end subroutine ACTION_dist_push definition
########################################################################

=item checkserver

Just tests connection, remote execution.

=cut

sub ACTION_checkserver {
  my $self = shift;

  my $data = $self->server_details;
  my $server = $data->{server} or die;
  my $dir = $data->{directory} or die;
  $dir .= '/downloads/';
  $self->jailshell_ssh($server, "test -e $dir") or
    die "'$dir' does not exist";
  $self->jailshell_ssh($server, "test '!' -e $dir/foo") or
    die "'$dir/foo' exists";
  $self->jailshell_ssh($server, "touch $dir/foo") or
    die "cannot make $dir/foo $!";
  $self->jailshell_ssh($server, "test -e $dir/foo") or
    die "'$dir/foo' could not be made";
  $self->jailshell_ssh($server, "rm $dir/foo") or
    die "cannot rm $dir/foo";
  $self->jailshell_ssh($server, "test '!' -e $dir/foo") or
    die "'$dir/foo' exists";
  print "ok\n";
}

=back

=cut

########################################################################
# NO MORE ACTIONS
########################################################################

=head1 Remote Execution

=head2 jailshell_ssh

Workaround for buggy, proprietary code.

Required for getting success/failure from cpanel's broken jailshell
implementation (which doesn't return the remote command exit status like
any good ssh shell would.)

  $self->jailshell_ssh($server, $command, @opts);

=cut

sub jailshell_ssh {
  my $self = shift;
  my ($server, $command, @opts) = @_;

  push(@opts, $self->ssh_opts($server));

  $VERBOSE and warn "# ssh $server @opts $command\n";
  $RUN_SSH or return(1); # pretend it is ok

  my ($in, $out, $err);
  my $token = time;
  require IPC::Run;
  my $ret = IPC::Run::run(['ssh', $server, @opts,
    "$command && echo $token ok"],
    \$in, \$out, \$err);
  # XXX stupid jailshell, now this isn't compatible with any actual ssh
  # implementation!
  unless($ret) {
    $err and die "command failed $err";
  }
  #$err and ($! = $err);
  return($out =~ m/$token ok\n$/);
} # end subroutine jailshell_ssh definition
########################################################################

=head2 ssh_rsync

The $to argument must not contain the "$server:" bit.

  $self->ssh_rsync($server, @args, $from, $to);

=cut

sub ssh_rsync {
  my $self = shift;
  my ($server, @args) = @_;
  my @ssh_opts = $self->ssh_opts($server);

  my $dest = pop(@args);
  $dest = $server . ':' . $dest;

  my @command = (
    'rsync',
    (scalar(@ssh_opts) ? '--rsh=' . join(' ', 'ssh', @ssh_opts) : ()),
    @args, $dest
  );

  $VERBOSE and warn "# ", join(" ", map({"'$_'"} @command)), "\n";
  $RUN_SSH or return(1);

  system(@command) and die $!;
} # end subroutine ssh_rsync definition
########################################################################

=head2 transfer_and_link

  $self->transfer_and_link($file);

=cut

sub transfer_and_link {
  my $self = shift;
  my ($src) = @_;

  my %opts = $self->_my_args;

  my $data = $self->server_details;
  my $server = $data->{server} or die;
  my $dir = $data->{directory} or die;
  $dir .= '/downloads/';

  require File::Basename;
  my $file = File::Basename::basename($src);

  $self->jailshell_ssh($server, "test '!' -e $dir/$file") or
    die "'$dir/$file' already exists";
  my $current = $file;
  my $nolink = $opts{nolink};
  # TODO change-up the filename scheme to have version first
  # still need some way to build the -current name out of it though --
  #   could require caller to pass the name in pieces?
  unless($current =~ s/-v\d+\.\d+\.\d+/-current/) {
    # allow a preview build, but don't ever link it as current
    $nolink = 1;
    ($current =~ s/-PRE[A-Z-]*\d+\.\d+.\d+/-current/) or
      die "cannot transform $current name";
  }
  $self->jailshell_ssh($server, "cp -H $dir/$current $dir/$file") or
    sub{$nolink ? warn @_ : die @_}->("cannot make copy");
  $self->ssh_rsync($server, '-cvz', $src, "$dir/$file");
  ## TODO link for bleed/etc when --version-force (or version-bump) is on
  unless($nolink) {
    $self->jailshell_ssh($server,
      "rm $dir/$current && ln -s $file $dir/$current"
    ) or die "link juggling failed";
  }
} # end subroutine transfer_and_link definition
########################################################################

=head2 server_details

Loads the yaml data.

  my $data = $self->server_details;

=cut

sub server_details {
  my $self = shift;

  $self->{server_details} and return($self->{server_details});
  require YAML::Syck;
  my ($data) = YAML::Syck::LoadFile('server_details.yml');
  if(my $keyring = $data->{keyring}) {
    foreach my $host (keys(%$keyring)) {
      $keyring->{$host} =~ s#^~#$ENV{HOME}/#;
    }
  }
  return($self->{server_details} = $data);
} # end subroutine server_details definition
########################################################################

=head2 ssh_opts

  my @opts = $self->ssh_opts($server);

=cut

sub ssh_opts {
  my $self = shift;
  my ($server) = @_;

  my $data = $self->server_details;
  my @opts;
  if(my $keyring = $data->{keyring}) {
    my $key = $keyring->{$server};
    push(@opts, ($key ? ('-i', $key) : ()));
  }
  return(@opts);
} # end subroutine ssh_opts definition
########################################################################

# vi:ts=2:sw=2:et:sta
1;
