package inc::dtRdrBuilder;

# Copyright (C) 2006 OSoft, Inc.
# License: GPL

use warnings;
use strict;

use base qw(Module::Build);
use Carp;

our $VERSION = '0.01';

my $perl = $^X;
if($^O eq 'darwin') {
  $perl =~ m/wxPerl/ or
    warn "'$perl' may not work for you on the GUI\n",
      "do 'wxPerl Build.PL' for best results\n\n";
}

=head1 NAME

dtRdrBuilder -  Custom build methods for dotReader

=head1 SYNOPSIS

Ask Eric

=cut

my @db_files = qw(
  SQL_Library.db
  drconfig.db
  );

my @db_dumps = map({"client/setup/$_.sql"} @db_files);

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

sub ACTION_glade {
  my $self = shift;
  # oops, glade expects to see this there
  my @keepers = qw(
    MainFrame.pm
    NoteEditor.pm
    TextViewer.pm
  );

  my $src_dir = 'lib/dtRdr/GUI/Wx/';
  my $gld_dir = 'client/';
  foreach my $file (@keepers) {
    rename($src_dir . $file, $gld_dir . $file)
      or die "error in migrating $file to $gld_dir $!";
    # glade misbehaves if we use a real package name, so we'll lie
    system($self->perl, '-i.bak', '-pe',
      's/^package dtRdr::GUI::Wx::/package /',
      $gld_dir . $file);
  }
  chdir('client') or die;
  warn "running wxglade\n";
  system('wxglade', '-g', 'perl', 'glade_src.wxg') and die;
  chdir('..') or die;
  warn "running fixup\n";
  # get the .pm's out of client and into lib ...
  foreach my $file (@keepers) {
    rename($gld_dir . $file, $src_dir . $file)
      or die "error in migrating $file from $gld_dir $!";
    # two wrongs make a right
    system($self->perl, '-i.bak', '-pe',
      's/^package /package dtRdr::GUI::Wx::/',
      $src_dir . $file);
    unlink($src_dir . $file . '.bak');
  }
  if (1) {
    # glade should quit generating stubs I don't want!
    for(glob('client/*.pm'), glob('client/*.pm.bak')) {
      warn "killing '$_'\n";
      unlink($_);
    }
    require File::Path;
    File::Path::rmtree('client/dtRdr');
  }
  foreach my $file (@keepers) {
    $self->run_perl_command(
      [
        'inc/bin/glade_autogen_fix.pl',
        $src_dir . $file
      ],
    );
  }
  # TODO: parse glade file and generate ro accessors
}

sub ACTION_run_client {
  my $self = shift;
  my (@args) = @_;
  $self->depends_on('code');
  exec($self->perl, '-Iblib/lib', 'client/app.pl', @{$self->{args}{ARGV}});
}
*ACTION_run = \&ACTION_run_client;

sub ACTION_testgui {
  my $self = shift;
  $self->generic_test(type => 'gui');
}

sub ACTION_testall {
  my $self = shift;

  my $p = $self->{properties};
  my @test_types = ('t',
    ($p->{testfile_types} ? keys(%{$p->{testfile_types}}) : ())
  ); 
  $self->generic_test(types => \@test_types);
}

sub ACTION_testpar {
  my $self = shift;
  $self->depends_on('par');
  $self->depends_on('starter_data');
  # ... now what? cd /tmp/ ... system ... ok?
  my $ft_file = $self->starter_data_dir . '/first_time';
  (-e $ft_file) or die "first_time file did not get created";
  system($self->parfilename) and die "bad exit status";
  (-e $ft_file) and die "first_time file did not get deleted";
  open(my $fh, '>', $ft_file); # putback
  print "ok\n";
} # end subroutine ACTION_testpar definition
########################################################################

sub ACTION_books {
  my $self = shift;
  my (@args) = @_;

  my $pdir = 'test_packages/';
  (-d $pdir) or die "cannot see '$pdir' directory";

  # TODO special copy+unzip for thout_1_0 books with internal gzipped
  # content (those are really just an svn hack)

  my @books;
  if(@args) {
    @books = @args;
  }
  else {
    @books = do {
      my $manifest = $pdir . 'BOOKMANIFEST';
      open(my $fh, '<', $manifest) or die "cannot open '$manifest' $!";
      map({chomp;$_} <$fh>);
    };
  }
  @books or die "eek";

  my $d_dir = "$pdir/0_jars";
  require File::Path;
  unless(-d $d_dir) {
    File::Path::mkpath($d_dir) or die "need $d_dir $!";
  }

  foreach my $book (@books) {
    # TODO make all of this into ./bin/drbook_builder or something

    my $destfile = "$d_dir/$book.jar";

    use Archive::Zip ();
    use File::Find;
    my @book_bits;
    find(sub {
      if(-d $_ and m/\.svn/) {
        $File::Find::prune = 1;
        return;
      }
      (-f $_) or return;
      m/^\./ and return;
      #warn "found $File::Find::name\n";
      push(@book_bits, $File::Find::name);
    }, $pdir . $book);
    
    # skip it if we've got one, see
    if($self->up_to_date(\@book_bits, $destfile)) {
      warn "$destfile is up-to-date\n";
      next;
    }
    
    my $zip = Archive::Zip->new();
    foreach my $bit (@book_bits) {
      my $string = do {
        open(my $fh, '<', $bit) or die "ack '$bit' $!";
        binmode($fh);
        local $/;
        <$fh>;
      };
      my $bitname = $bit;
      $bitname =~ s#.*$book/+##;
      $zip->addString($string, $bitname);
    }
    warn "making $book.jar\n";
    $zip->writeToFileNamed( $destfile ) == Archive::Zip::AZ_OK
     or die 'write error';
  }
} # end subroutine ACTION_books definition
########################################################################

sub ACTION_podserver {
  my $self = shift;
  # TODO make this cooler
  fork or exec(qw(xterm -g 30x5 -e podserver inc lib util));
} # end subroutine ACTION_podserver definition
########################################################################

sub ACTION_compile {
  my $self = shift;

  # This line of thought has basically been dropped.  Nice in theory,
  # but terribly messy in practice.

  die "nope";

  # XXX use find_pm_files instead?
  #my %map = $self->_module_map;
  my $files = $self->find_pm_files;
  #basically: $ perl -MO=Bytecode,-H,-oblib/lib/dtRdr.pmc -Ilib lib/dtRdr.pm

  while (my ($file, $dest) = each %$files) {
    my $to_path = File::Spec->catfile($self->blib, $dest);
    if($file =~ m/dtRdr\/HTML/) { # these are too touchy
      $self->copy_if_modified(from => $file, to => $to_path);
      next;
    }
    # nice to have somewhere to go
    File::Path::mkpath(File::Basename::dirname($to_path), 0, 0777);
    next if $self->up_to_date($file, $to_path); # Already fresh
    my @command = (
      "-MO=Bytecode,-b,-H,-o$to_path", '-Ilib', $file
    );
    $self->run_perl_command(\@command);
  }
} # end subroutine ACTION_compile definition
########################################################################

=begin note

# -c adds some time to the build
PERL5LIB="$PERL5LIB:lib:client" pp -o dotreader.exe -c -z 9 -a client/data -g -I lib -I client client/app.pl

pp -o app.exe -c -z 9 -a client/data -g
-I lib/dtRdr
-M dtRdr
-M XML::Parser::Expat
-M Wx::ActiveX
-M Wx::DND
-M Wx::DocView
-M Wx::FS
-M Wx::Grid
-M Wx::Help
-M Wx::MDI
-M Wx::Print
-M Wx::Socket
-M WX::Calendar

@libs
client/app.pl

and on windows...
perl -e "use Wx::build::Options; use Wx::build::Config; print Wx::build::Config->new()->get_package;"
perl -e "use Wx::build::Options; use Wx::build::Config; print Wx::build::Config->new()->wx_config(qq(libs));"

dep check vs not -- reduces build time significantly (18s vs 30), but
that might be only a matter of the number of modules (without -c, we
don't have a clue as to what we need unless we have an explicit
manifest.)

compressed vs not -- z9 adds 11s to build (run seems to not mind so much
-- 8.5 vs 9.2 and 3.4 vs 3.2)

=end note

=cut

sub parfilename { $_[0]->par_build_dir . '/dotreader.exe'};
sub starter_data_dir { $_[0]->par_build_dir . '/dotreader-data'};
use constant {
  datadir => 'blib/pardata',
  clientdata => 'client/data',
  par_build_dir => 'binary_build',
  parmanifest   => 'blib/parmanifest',
};
sub _my_args {
  my $self = shift;
  my %args = $self->args;
  # TODO index this by the calling subroutine?
  my @bin_opts = qw(
    clean
    dev
    nolink
  );
  foreach my $opt (@bin_opts) {
    $args{$opt} = 1 if(exists($args{$opt}));
  }
  return(%args);
}
sub ACTION_par {
  my $self = shift;

  my %args = $self->_my_args;
  my $devmode = $args{dev} || 0;
  $devmode and warn "building with console";

  my $parfile = $self->parfilename;
  { # do we need to do anything?
    my @sources = (
      keys(%{$self->find_pm_files}), 
      __FILE__, # XXX to thisfile or not to thisfile?
      );
    if($self->up_to_date(\@sources, $parfile)) {
      warn "$parfile is up to date";
      return;
    }
  }
  $self->depends_on('code');
  $self->depends_on('datadir');

  my @wxlibs;
  my @other_dll;
  if($^O eq 'linux') {
    require IPC::Run;
    my $prefix;
    {
      my ($in, $out, $err);
      IPC::Run::run([qw(wx-config --prefix)], \$in, \$out, \$err) or die;
      $out or die;
      chomp($out);
      $prefix = $out;
    }
    {
      my ($in, $out, $err);
      IPC::Run::run([qw(wx-config --libs)], \$in, \$out, \$err) or die;
      $out or die;
      @wxlibs = map({s/^-l//; "$prefix/lib/lib$_.so"} # glob?
        grep(/^-l/, split(/ /, $out)));
      0 and warn "wx libs: @wxlibs";
    }
    push(@wxlibs, qw(
      tiff
      wxmozilla_gtk2u-2.6
    ));
    push(@other_dll, qw(
      /usr/lib/libstdc++.so.6
    ));
  }
  elsif($^O eq 'MSWin32') {
    @wxlibs = map({'C:/Perl/site/lib/auto/Wx/' . $_}
      qw(
        Wx.dll
        mingwm10.dll
        wxbase26_gcc_custom.dll
        wxbase26_net_gcc_custom.dll
        wxbase26_xml_gcc_custom.dll
        wxmsw26_adv_gcc_custom.dll
        wxmsw26_core_gcc_custom.dll
        wxmsw26_gl_gcc_custom.dll
        wxmsw26_html_gcc_custom.dll
        wxmsw26_media_gcc_custom.dll
        wxmsw26_stc_gcc_custom.dll
        wxmsw26_xrc_gcc_custom.dll
      ),
    );
    if(0) { # make that unicode
      s/26_/26u_/ for(@wxlibs);
    }

  }
  else {
    # mac gets an appbundle
    die "building a par for VMS now, eh?";
  }

  use Config;

  if($^O eq 'linux') {
    $ENV{$Config{ldlibpthname}} =
      join($Config{path_sep}, qw(
        /usr/lib
        /usr/local/lib
      ));
  }
  
  my @add_mods = qw(
    dtRdr::Library::SQLLibrary
    Log::Log4perl::Appender::File
  );

  my @modules = grep({$_ !~ m/^dtRdr::HTMLShim/} keys(%{{$self->_module_map()}}));

  push(@modules,
    ($^O eq 'linux') ? (
      'dtRdr::HTMLShim::WxMozilla',
    ) : (),
    ($^O eq 'MSWin32') ? (
      'dtRdr::HTMLShim::ActiveXIE',
      'Win32',
      'Wx::ActiveX::IE',
      'Wx::DocView',
      map({'Win32::OLE::'.$_} qw(
        Const Enum Lite NLS TypeInfo Variant
      )),
      # XXX this is apparently not the answer, since it seems that
      # something is flushing @INC in the process?
      (0 ? (
        'Config_m', # XXX got a "Can't locate ... in @INC" once
        'ExtUtils::FakeConfig'
      ) :
      ()
      )
    ) : (),
    'dtRdr::HTMLShim::WxHTML'
  );
  
  require File::Path;
  $args{clean} and File::Path::rmtree([$self->par_build_dir]);
  File::Path::mkpath([$self->par_build_dir]);

  # Try to grab a cache of dependencies
  my $parmanifest = $self->parmanifest;
  my @cached_deps;
  if(-e $parmanifest) {
    warn "got $parmanifest -- skipping dependency-check compilation\n";
    open(my $fh, '<', $parmanifest);
    @cached_deps = grep(
      {
        $_ !~ m#^auto/# and
        $_ !~ m#^unicore/#
      }
      map({chomp;s#^lib/##;$_} 
        grep({m#^lib/# and m/\.pm$/} <$fh>)
      )
    );
    for(@cached_deps) { s#/+#::#g; s/\.pm$//;}
  }

  # got to have this bit for windows at least
  local $ENV{PERL5LIB} =
    (defined($ENV{PERL5LIB}) ? $ENV{PERL5LIB} . $Config{path_sep} : '') .
      'blib/lib';

  use File::Spec;
  my @command = (
    $self->pp,
    '-o', $parfile,
    ( # if we know what we need, let's quit checking for it
      scalar(@cached_deps) ?
      map({('-M', $_)} @cached_deps) :
      '--compile'
    ),
    qw(-z 9),
    ($devmode ? () : '--gui'), # only have console if requested
    '-a',  $self->datadir . ';data',
    '--icon',
      File::Spec->rel2abs(
        'client/data/gui_default/icons/dotreader.ico'
      ),
    qw(-I blib/lib),
    map({('-l', $_)} @wxlibs, @other_dll),
    map({('-M', $_)} @add_mods, @modules),
    'client/app.pl',
  );
  warn "running pp",
    (0 ?
      ("\n  ", join(" ", @command)) :
      (scalar(@cached_deps) ?
        '' :
        ' (no cached dependencies)'
      )
    ),
    "\n";
  my ($in, $out, $err);
  IPC::Run::run(\@command, \$in, \*STDOUT, \$err) or die "$! $^E $? $err";
  warn "built $parfile\n";
} # end subroutine ACTION_par definition
########################################################################

sub pp {
  my $self = shift;
  return(($^O eq 'MSWin32') ? ($self->perl, 'c:/perl/bin/pp') : ('pp'));
}

sub ACTION_datadir {
  my $self = shift;

  my $dest_dir = $self->datadir;
  $self->delete_filetree($dest_dir);
  File::Path::mkpath([$dest_dir]);

  warn "populating $dest_dir\n";
  require File::Find;

  require Cwd;
  my $ret_dir = Cwd::getcwd;
  chdir($self->clientdata) or die;
  File::Find::find({
    no_chdir => 1,
    wanted => sub {
    (-d $_) and return;
    #warn $_;
    m/\..*\.swp/ and return;
    if(-d $_ and m/\.svn/) {
      $File::Find::prune = 1;
      return;
    }
    $self->copy_if_modified(
      from    => $_,
      to      => "$ret_dir/$dest_dir/$_",
      verbose => 0,
    );
  }}, '.');
  chdir($ret_dir) or die;

  if(-e "$dest_dir/" . $self->release_file) {
    unlink("$dest_dir/" . $self->release_file) or die;
  }
  $self->write_release_file($dest_dir);

  require File::Copy;
  for (qw(log.conf.tmpl log.conf)) {
    unlink("$dest_dir/$_") or die $_;
    File::Copy::copy("$dest_dir/log.conf.par", "$dest_dir/$_");
  }

  foreach my $file (qw(LICENSE COPYING)) {
    $self->copy_if_modified(
      from    => $file,
      to      => "$dest_dir/$file",
      verbose => 1,
    );
  }

} # end subroutine ACTION_datadir definition
########################################################################

sub ACTION_repar {
  my $self = shift;

  my @args = @{$self->{args}{ARGV}};
  my %args = map({ $_ => 1 } @args);

  if($args{nodata}) {
    warn "skipping datadir generation";
  }
  else {
    $self->depends_on('datadir');
  }

  use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

  my $filename = 'binary_build/dotreader.exe';

  my $src_dir = $self->datadir;
  (-e $src_dir) or
    die "you need to unset NO_DATA or manually build $src_dir";

  my $zip = Archive::Zip->new();
  $zip->read($filename) == AZ_OK or
    die("'$filename' is not a valid zip file.");
  $zip->updateTree($src_dir, 'data', sub {-f });
  $zip->overwrite( $filename ) == Archive::Zip::AZ_OK or die 'write error';
  undef($zip);

  rename($filename, "$filename.par") or die;
  system($self->pp, '-o', $filename, "$filename.par") and die;
  unlink("$filename.par") or warn "cannot remove '$filename.par' $!";
  warn "ok\n";
} # end subroutine ACTION_repar definition
########################################################################


sub ACTION_parmanifest {
  my $self = shift;

  require Archive::Zip;
  my $zip = Archive::Zip->new;
  my $filename = $self->parfilename;
  $zip->read($filename);
  my $member = $zip->memberNamed('MANIFEST');
  my $parmanifest = $self->parmanifest;
  open(my $fh, '>', $parmanifest) or
    die "cannot write to $parmanifest $!";
  print $fh $zip->contents($member);
} # end subroutine ACTION_parmanifest definition
########################################################################

# XXX icky name -- should be starter_data or something
sub ACTION_starter_data {
  my $self = shift;
  my %args = $self->_my_args;

  my $data_dir = $self->starter_data_dir . '/';

  require File::Path;
  if($args{clean}) {
    my $dir = $data_dir;
    $dir =~ s#/+$##; # Win32 nit
    File::Path::rmtree($dir);
  }
  File::Path::mkpath([$data_dir]);

  { # touch this
    warn "touch first_time file\n";
    open(my $fh, '>', $data_dir . 'first_time') or
      die "cannot touch first_time $!";
  }

  $self->copy_if_modified(
    from    => 'client/setup/default_drconfig.yml',
    to      => $data_dir . 'drconfig.yml',
    verbose => 1,
  );

  # TODO have a manifest for shippable books?
  my @books = (
    map({'test_packages/' . $_}
      map({$_ . '.jar'}
        qw(
          dotReader_beta_QSG
          other/Alienation_Victim
          other/publication_556
          other/rebel-w-o-car
          other/seventy_five_times
        )
      ),
    ),
  );
  foreach my $book (@books) {
    (-e $book) or die "need '$book' to build starter_data";
  }

  my $libfile = $data_dir . 'default_library.yml';
  my $libdir = $libfile;
  $libdir =~ s/\.yml//;
  require File::Basename;
  my @destbooks = map({
    $libdir . '/' . File::Basename::basename($_)
  } @books);
  unless($self->up_to_date(\@books, \@destbooks)) { # Already fresh
    warn "create $libfile\n";
    $self->run_perl_script(
      'util/mk_library', [],
      [
        '-f',
        $libfile,
        @books
      ],
    );
  }

  # TODO add some annotation data, bells, whistles, etc

} # end subroutine ACTION_starter_data definition
########################################################################


sub server_details {
  my $self = shift;
  require YAML::Syck;
  my ($data) = YAML::Syck::LoadFile('server_details.yml');
  return($data);
} # end subroutine server_details definition
########################################################################

{ # kind of silly closure
  my $dosystem = sub {
    warn "# @_\n";
    1 and return(system(@_));
    return 0;
  };
sub ACTION_binpush {
  my $self = shift;

  my @args = @{$self->{args}{ARGV}};
  my $release = shift(@args);
  my %opts = $self->_my_args;
  $release = $opts{release} unless(defined($release));
  $release or die "must have release name"; # TODO look it up?
  $release =~ m/ / and die;

  my $data = $self->server_details;
  my $server = $data->{server} or die;
  my $dir = $data->{directory} or die;
  $dir .= "/$^O" unless($^O eq 'MSWin32');

  {
    # only good way to ensure it isn't there already because BSD won't
    # return remote command exit status
    my ($in, $out, $err);
    require IPC::Run;
    IPC::Run::run(['ssh', $server, "test '!' -e $dir/$release && echo ok"],
      \$in, \$out, \$err) or die "command failed $err";
    ($out eq "ok\n") or die "'$dir/$release' already exists";
  }

  $dosystem->('ssh', $server, 
    join(" && ",
      "cp -RH $dir/current $dir/$release",
      (
        $opts{nolink} ? () :
        ("rm $dir/current", "ln -s $release $dir/current")
      ),
    )
  ) and die;
  $dosystem->('rsync', '-rvz', 'binary_build/', 
    $server . ':' . $dir . '/' . $release . '/') and die;

} # end subroutine ACTION_binpush definition
########################################################################

=head2 bindistribute

  $self->bindistribute($data);

=cut

sub bindistribute {
  my $self = shift;
  my ($data) = @_;

  if($data->{distribute}) {
    my @dirs = @{$data->{distribute}};
    foreach my $dest (@dirs) {
      $dest =~ s#/*$#/#;
      $dosystem->('rsync', '--delete', '-rv',
        $self->par_build_dir . '/', $dest
      ) and die;
    }
  }
} # end subroutine bindistribute definition
########################################################################

sub ACTION_bindistribute {
  my $self = shift;

  my $data = $self->server_details;
  $self->bindistribute($data);
} # end subroutine ACTION_bindistribute definition
########################################################################
} # end closure

# TODO put this in dtRdr.pm?
use constant {release_file => 'dotreader_release'};
sub write_release_file {
  my $self = shift;
  my ($location) = @_;

  # TODO let this get a different value from somewhere
  my $release = 'svn' . svn_rev();
  if(my $tag = svn_tag()) {
    $release = $tag . " ($release)";
  }

  my $file = "$location/" . $self->release_file;
  open(my $fh, '>', $file) or die "cannot write $file ($!)";
  print $fh $release;
}
sub svn_rev {
  require IPC::Run;
  unless(-e '.svn') {
    my ($in, $out, $err);
    my @command = ('svk', 'info');
    ($^O eq 'MSWin32') and return('notsvn'); # bah
    IPC::Run::run(\@command, \$in, \$out, \$err) or return("notsvn");
    my ($rev) = grep(/^Revision/, split(/\n/, $out));
    $rev or die "can't find revision in output >>>$out<<<";
    $rev =~ s/Revision: *//;
    return('svk' . $rev);
  }
  my ($in, $out, $err);
  my @command = ('svn', 'info');
  IPC::Run::run(\@command, \$in, \$out, \$err) or die "eek $err";
  my ($rev) = grep(/^Revision/, split(/\n/, $out));
  $rev or die "can't find revision in output >>>$out<<<";
  $rev =~ s/Revision: *//;
  return($rev);
}
sub svn_tag {
  (-e '.svn') or return();
  my ($in, $out, $err);
  my @command = ('svn', 'info');
  require IPC::Run;
  IPC::Run::run(\@command, \$in, \$out, \$err) or die "eek $err";
  my ($url) = grep(/^URL/, split(/\n/, $out));
  $url or die "can't find URL in output >>>$out<<<";
  $url =~ s/URL: *//;
  if($url =~ m#/tags/([^/]+)(?:/|$)#) {
    return($1);
  }
  return();
}


sub ACTION_binary_release {
  my $self = shift;
  $self->depends_on('par');
  $self->depends_on('starter_data');
} # end subroutine ACTION_binary_release definition
########################################################################

sub ACTION_traceuse {
  my $self = shift;
  # XXX not my favorite way to do this
  my $err = _get_used();
  my @modules = map({s/,.*//;$_} grep(/,/, split(/\n\s*/, $err)));
  print join("\n", @modules, '');
} # end subroutine ACTION_traceuse definition
########################################################################

sub ACTION_trace {
  my $self = shift;
  my $err = _get_used();
  print $err;
} # end subroutine ACTION_trace definition
########################################################################

=head2 _get_used

  _get_used();

=cut

sub _get_used {
  # hmm.  Devel::TraceUse vs Module::ScanDeps
  require IPC::Run;
  my ($in, $out, $err);
  my @command = (
    $perl, qw(-d:TraceUse -Ilib -e), 'require("client/app.pl")'
  );
  IPC::Run::run(\@command, \$in, \$out, \$err);
  $out and die;
  return($err);
} # end subroutine _get_used definition
########################################################################

=head2 _module_map

  my %map = _module_map()

=cut

sub _module_map {
  # /me shakes fist at Module::Build, pokes around in guts...
  # my $pm = $self->find_pm_files;
  # die join("\n", map({"$_ => $pm->{$_}"} keys(%$pm)));
  require File::Find;
  my @files;
  File::Find::find(sub {
    /\.pm$/ or return;
    push(@files, $File::Find::name);
    }, 'lib/');
  my %modmap = map({
    my $mod = $_;
    $mod =~ s#lib/##;
    $mod =~ s#\\|/#::#g;
    $mod =~ s/\.pm$// or die;
    $mod => $_;
    }
    @files
  );
  return(%modmap);
} # end subroutine _module_map definition
########################################################################

=head2 find_pm_files

Overridden to eliminate platform-specific deps.

  $self->find_pm_files;

=cut

sub find_pm_files {
  my $self = shift;
  my $files = $self->SUPER::find_pm_files;

  my @deletes;
  unless($^O eq 'MSWin32') {
    push(@deletes,
      'dtRdr::HTMLShim::ActiveXIE',
      'dtRdr::HTMLShim::ActiveXMozilla',
    );
  }
  unless($^O eq 'darwin') {
    push(@deletes,
      'dtRdr::HTMLShim::WebKit'
    );
  }
  unless($^O eq 'linux') {
    push(@deletes,
      'dtRdr::HTMLShim::WxMozilla'
    );
  }
  for(@deletes) {
    s#::#/#g;
    $_ = 'lib/' . $_ . '.pm';
  }
  delete($files->{$_}) for(@deletes);
  return($files);
} # end subroutine find_pm_files definition
########################################################################

=begin devnotes

=head1 WHAT'S ALL THIS THEN?

I added the concept of test types (or groups) to Module::Build in this
subclass.  This really needs to go upstream.

=end devnotes

=cut

# STOLEN/HACKED CODE {{{
sub ACTION_test {
  my $self = shift;

  $self->depends_on('books'); # XXX ick -- need to get the rest upstream

  $self->generic_test(type => 't');
}
# stolen from M::B::B::ACTION_test
sub generic_test {
  my $self = shift;
  (@_ % 2) and
    croak('Odd number of elements in argument hash');
  my %args = @_;
  
  my @types = (
    (exists($args{type})  ? $args{type} : ()), 
    (exists($args{types}) ? @{$args{types}} : ()),
    );
  @types or croak "need some types of tests to check";

  my $p = $self->{properties};
  require Test::Harness;
  
  $self->depends_on('code');
  
  # Do everything in our power to work with all versions of Test::Harness
  my @harness_switches = $p->{debugger} ? qw(-w -d) : ();
  local $Test::Harness::switches    = join ' ', grep defined, $Test::Harness::switches, @harness_switches;
  local $Test::Harness::Switches    = join ' ', grep defined, $Test::Harness::Switches, @harness_switches;
  local $ENV{HARNESS_PERL_SWITCHES} = join ' ', grep defined, $ENV{HARNESS_PERL_SWITCHES}, @harness_switches;
  
  $Test::Harness::switches = undef   unless length $Test::Harness::switches;
  $Test::Harness::Switches = undef   unless length $Test::Harness::Switches;
  delete $ENV{HARNESS_PERL_SWITCHES} unless length $ENV{HARNESS_PERL_SWITCHES};
  
  local ($Test::Harness::verbose,
	 $Test::Harness::Verbose,
	 $ENV{TEST_VERBOSE},
         $ENV{HARNESS_VERBOSE}) = ($p->{verbose} || 0) x 4;

  # Make sure we test the module in blib/
  local @INC = (File::Spec->catdir($p->{base_dir}, $self->blib, 'lib'),
		File::Spec->catdir($p->{base_dir}, $self->blib, 'arch'),
		@INC);

  # Filter out nonsensical @INC entries - some versions of
  # Test::Harness will really explode the number of entries here
  @INC = grep {ref() || -d} @INC if @INC > 100;
  
  my $tests = $self->find_test_files(@types);

  if (@$tests) {
    # Work around a Test::Harness bug that loses the particular perl
    # we're running under.  $self->perl is trustworthy, but $^X isn't.
    local $^X = $self->perl;
    Test::Harness::runtests(@$tests);
  } else {
    $self->log_info("No tests defined.\n");
  }

  # This will get run and the user will see the output.  It doesn't
  # emit Test::Harness-style output.
  if (-e 'visual.pl') {
    $self->run_perl_script('visual.pl', '-Mblib='.$self->blib);
  }
}
sub expand_test_dir {
  my $self = shift;
  my ($dir, @types) = @_;

  my $p = $self->{properties};

  my @tfiles;
  my @typelist;
  foreach my $type (@types) {
    # old-school
    if($type eq 't') { push(@typelist, 't'); next; }

    defined($p->{testfile_types}) or
      Carp::confess("cannot have typed testfiles without 'testfile_types' data");
    defined($p->{testfile_types}{$type}) or
      croak "no testfile_type '$type' is defined";
    push(@typelist, $p->{testfile_types}{$type});
  }
  #warn "expand_test_dir($dir, @types) @typelist";
  #do('./util/BREAK_THIS') or die;
  if($self->recursive_test_files) {
    push(@tfiles, @{$self->rscan_dir($dir, qr{^[^.].*\.$_$})})
      for(@typelist);
  }
  else {
    push(@tfiles, glob(File::Spec->catfile($dir, $_)))
      for(map({"*.$_"} @typelist));
  }
  $p->{verbose} and warn "found ", scalar(@tfiles), " test files\n";
  return(sort(@tfiles));
}

sub find_test_files {
  my $self = shift;
  my (@types) = @_;

  my $p = $self->{properties};
  
  if (my $files = $p->{test_files}) {
    $files = [keys %$files] if UNIVERSAL::isa($files, 'HASH');
    $files = [map { -d $_ ? $self->expand_test_dir($_, @types) : $_ }
	      map glob,
	      $self->split_like_shell($files)];
    
    # Always given as a Unix file spec.
    return [ map $self->localize_file_path($_), @$files ];
    
  } else {
    # Find all possible tests in t/ or test.pl
    my @tests;
    push @tests, 'test.pl'                                  if -e 'test.pl';
    push @tests, $self->expand_test_dir('t', @types)        if -e 't' and -d _;
    return \@tests;
  }
}
# STOLEN/HACKED CODE }}}

=head1 ACTIONS

=over 4

=item db_load

Create new sqlite db's from dumpfiles.

=item db_smash

Deletes existing database files (DOES NOT CHECK THEM YET!) and then does
db_load.

=item db_version

Displays your DBD::SQlite and sqlite3 versions.

=item glade

Regenerate and fixup MainFrame.pm

=item run_client

basically:

  perl -Ilib client/app.pl

=item run

Alias to the C<run_client> action.

=item testgui

Run the gui tests.

=item testall

Run all tests.

=item books

Assemble the book packages per the BOOKMANIFEST file.

=item podserver

Start a server on 8088 (or so)

=item binary_release

Builds the binary and starter data for the current platform.

=item par

Build a 'binary_build/dotreader.exe' par.

By default, this has no console on windows.  Use the "dev" pseudo-option
to enable console output (only matters on windows.)

  build par dev

=item datadir

Build the 'data/' directory that goes inside the par in blib/pardata/.

=item repar

Build and repackage the 'data/' directory for the par.

  ./Build repar

  ./Build repar nodata

=item starter_data

Assemble a default config, library, and some free books in
"binary_build/dotreader-data/"

=item parmanifest

Extract the MANIFEST file from the current par (saves compilation time
on the next BUILD par)

=item binpush

Push and symlink binary_build/ to the server/directory specified in
server_details.yml

  server: example.com
  directory: foo
  distribute:
    - user@host:dir/

=item bindistribute

Distribute binary_build/ to each of the @distribute entries in the
server_details.yml file.

=item traceuse

List used modules.

=back

=head1 AUTHOR

Eric Wilhelm <ewilhelm at cpan dot org>

http://scratchcomputing.com/

=head1 COPYRIGHT

Copyright (C) 2006 Eric L. Wilhelm and OSoft, All Rights Reserved.

=head1 NO WARRANTY

Absolutely, positively NO WARRANTY, neither express or implied, is
offered with this software.  You use this software at your own risk.  In
case of loss, neither Eric Wilhelm, nor anyone else, owes you anything
whatseover.  You have been warned.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# vi:ts=2:sw=2:et:sta
1;
