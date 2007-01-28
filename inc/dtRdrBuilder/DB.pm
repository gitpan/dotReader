package inc::dtRdrBuilder::DB;

# db-related junk

use warnings;
use strict;
use Carp;

my @db_files = qw(
  SQL_Library.db
  drconfig.db
  );

my @db_dumps = map({"client/setup/$_.sql"} @db_files);

=head1 ACTIONS

=over

=item db_load

Create new sqlite db's from dumpfiles.

=cut

# these two could use some refactoring
sub ACTION_db_load {
  my $self = shift;
  my ($dumps, $files) = @_;
  $files ||= [@db_files];
  $dumps ||= [@db_dumps];

  my @commands = map(
    {["sqlite3", $files->[$_], '.read '. $dumps->[$_]]}
    0..$#$files
  );
  foreach my $com (@commands) {
    warn "running '@$com'\n";
    (-e $com->[1]) and
      die "db file '$com->[1]' exists -- that gets too ugly.\n\n  STOP\n";
    system(@$com) and warn "error $!";
  }
}

=item db_smash

Deletes existing database files (DOES NOT CHECK THEM YET!) and then does
db_load.

=cut

sub ACTION_db_smash {
  my $self = shift;
  my ($dumps, $files) = @_;
  $files ||= [@db_files];
  $dumps ||= [@db_dumps];

  for(my $i = 0; $i < @$files ; $i++) {
    (-e $files->[$i]) or next;
    warn "removing $files->[$i]\n";
    unlink($files->[$i]) or die "cannot remove '$files->[$i]'";
  }
  $self->ACTION_db_load($dumps, $files);
}

=item db_version

Displays your DBD::SQlite and sqlite3 versions.

=cut

sub ACTION_db_version {
  my $self = shift;
  # ick. guess I have to have a db?

  require File::Temp;
  my $tempfile = File::Temp::tempdir(TMPDIR=>1, CLEANUP => 1) . '/check.db';
  $tempfile =~ s#\\#/#g; # windows fix :-(
  my @checks = (
    [$self->perl, '-e', '
      use DBD::SQLite;
      use DBI;
      my $dbh = DBI->connect("dbi:SQLite:' . $tempfile . '", "", "");
      print DBD::SQLite::db::_get_version($dbh), "\n";'
    ],
    [
    qw(sqlite3 -version)
    ],
    );
  my @results;

  require IPC::Run;

  foreach my $check (@checks) {
    my ($in, $out, $err);
    eval{ IPC::Run::run($check, \$in, \$out, \$err) };
    $err and warn $err;
    chomp($out);
    push(@results, $out);
  }
  (@results == 2) or warn "eek";
  warn(($results[0] eq $results[1]) ? 'yay!' : 'mismatch!', "\n");
  print "DBD::SQLite:  $results[0]\n";
  print "sqlite3:      $results[1]\n";

}

=back

=cut

1;
