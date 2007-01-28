package inc::dtRdrBuilder;
our $VERSION = '0.01';

# Copyright (C) 2006, 2007 by Eric Wilhelm and OSoft, Inc.
# License: GPL

use warnings;
use strict;
use Carp;

use base qw(
  inc::MBwishlist
  Module::Build
  inc::dtRdrBuilder::Accessory
  inc::dtRdrBuilder::DB
  inc::dtRdrBuilder::DepCheck
  inc::dtRdrBuilder::Distribute
);

my $perl = $^X;
if($^O eq 'darwin') {
  $perl =~ m/wxPerl/ or
    warn "'$perl' may not work for you on the GUI\n",
      "do 'wxPerl Build.PL' for best results\n\n";
}
BEGIN {
  if($^O eq 'darwin') {
    eval { require Module::Build::Plugins::MacBundle };
    $@ and warn "features missing -- $@";
    #Module::Build::Plugins::MacBundle->import('ACTION_appbundle')
    #  unless($@);
  }
} # end BEGIN

=head1 NAME

dtRdrBuilder -  Custom build methods for dotReader

=head1 SYNOPSIS

  Build Build Build Build Build Build
        Build Build Build Build Build Build
  Build Build Build             Build       Build Build
        Build       Build Build       Build Build Build
              Build             Build
        Build Build Build Build
                                                  Build
              Build Build
                                Build Build Build
  Build Build Build
  Build
  
  Build
  
  
  Build

=head1 General Notes

The build system has occassionally been a catch-all for stuff that
should maybe be a standalone utility, etc.  Thus, it is subject to the
same laws of chaos as the rest of the codebase, except that it has no
tests.

Therefore, code with the goal of making this package smaller.

=head2 Avoid Static Dependencies

Not only do they break CPAN-based builds/tests, they also make it harder
to yank-out the code and put it where it should be.

=cut

=head1 ACTIONS

=over 4

=cut

=item testgui

Run the gui tests.

=cut

sub ACTION_testgui {
  my $self = shift;
  $self->generic_test(type => 'gui');
}

=item testbinary

Test the built binary.  This runs (mostly) in the same context as a
distributed .par/.app bundle.

Requires a graphical display, but (hopefully) no interaction.

=cut

sub ACTION_testbinary {
  my $self = shift;

  # setup
  my $token = time;
  local $ENV{DOTREADER_TEST} = qq(print "ok $token\n";);

  # disable gui errors
  local $ENV{JUST_DIE} = 1;

  # zero-out @INC on mac
  local $ENV{PW_NO_INC} = 1;

  my ($out, $err) = $self->run_binary;

  # check
  $out or die "not ok\n";
  ($out =~ m/^ok $token/) or die "not ok\n";

  # woot
  print "ok\n";
} # end subroutine ACTION_testbinary definition
########################################################################

=item runbinary

Runs the binary interactively.

=cut

sub ACTION_runbinary {
  my $self = shift;
  $self->run_binary;
} # end subroutine ACTION_runbinary definition
########################################################################

=item par

Build a binfilename() (e.g. 'binary_build/dotreader.exe') par.

By default, this has no console on windows.  Use the "dev" pseudo-option
to enable console output (only matters on windows.)

  build par dev

=cut

sub ACTION_par {
  my $self = shift;

  my %args = $self->_my_args;

  # just switch to mini mode
  return($self->depends_on('par_parts')) if($args{mini});

  my $devmode = $args{dev} || 0; # XXX rename (dev should mean no deps?)
  $devmode and warn "building with console";

  my $parfile = $self->binfilename;
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

  use Config;

  if($^O eq 'linux') {
    $ENV{$Config{ldlibpthname}} =
      join($Config{path_sep}, qw(
        /usr/lib
        /usr/local/lib
        /usr/lib/mozilla
      ));
  }
  
  my @add_mods = ($self->additional_deps);

  my @modules =
    grep({$_ !~ m/^dtRdr::HTMLShim/} keys(%{{$self->_module_map()}}));

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
    ) : (),
    'dtRdr::HTMLShim::WxHTML'
  );
  
  require File::Path;
  $args{clean} and File::Path::rmtree($self->binary_build_dir);
  File::Path::mkpath($self->binary_build_dir);

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
  else {
    if(1) {
      # way faster compile
      warn "pre-compiling dependencies\n";
      @cached_deps = $self->scan_deps(
        modules => [@add_mods, @modules],
        string => $self->dependency_hints,
      );
    }
    else {
      push(@add_mods,
        $self->scan_deps(string => $self->dependency_hints));
    }
  }

  # got to have this because Module::ScanDeps thru ~0.71 doesn't pass
  # the -I opts into the subprocess which does the compile
  local $ENV{PERL5LIB} =
    (defined($ENV{PERL5LIB}) ? $ENV{PERL5LIB} . $Config{path_sep} : '') .
      'blib/lib';

  require File::Spec;
  my @command = (
    $self->which_pp,
    '-o', $parfile,
    ( # if we know what we need, let's quit checking for it
      scalar(@cached_deps) ?
      map({('-M', $_)} @cached_deps) :
      '--compile'
    ),
    #'-n', # seems to lose a lot of stuff
    qw(-z 9),
    ($devmode ? () : '--gui'), # only have console if requested
    '-a',  $self->datadir . ';data',
    '--icon',
      File::Spec->rel2abs(
        'client/data/gui_default/icons/dotreader.ico'
      ),
    qw(-I blib/lib),
    map({('-l', $_)} $self->external_libs),
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
  0 and (@command = (qw(strace -o /tmp/stracefile), @command));
  IPC::Run::run(\@command, \$in, \*STDOUT, \*STDERR) or die "$! $^E $? $err";
  warn "built $parfile\n";
} # end subroutine ACTION_par definition
########################################################################

=item par_parts

=cut

sub ACTION_par_parts {
  my $self = shift;

  my %args = $self->_my_args;

  my $devmode = $args{dev};

  $self->depends_on('par_mini');

  my $par_mini = $self->par_mini;

  # set this so the filename comes out right
  local $self->{args}{mini} = 1;
  my $exe_file = $self->binfilename;
  my @command = (
    $self->which_pp,
    '-o', $exe_file,
    qw(-z 9),
    ($devmode ? () : '--gui'), # only have console if requested
    '--icon',
      File::Spec->rel2abs(
        'client/data/gui_default/icons/dotreader.ico'
      ),
    $par_mini
  );
  warn "pp for $exe_file\n";
  system(@command) and die "$!";
  warn "par_parts done\n";
} # end subroutine ACTION_par_parts definition
########################################################################

=item par_mini

Build an archive with all of the project code.

=cut

sub ACTION_par_mini {
  my $self = shift;
  $self->depends_on('par_core');

  # egg, meet chicken
  $self->depends_on('par_pl');

  my $par_mini = $self->par_mini;
  my $par_seed = $self->par_seed;

  warn "zip $par_mini\n";
  require Archive::Zip;
  my $zip = Archive::Zip->new();
  $zip->read($par_seed) == Archive::Zip::AZ_OK or
    die("'$par_seed' is not a valid zip file.");
  $zip->updateMember('script/dotReader.pl', $self->parmain_pl) or
    die "failed to add script";
  $zip->overwriteAs($par_mini) == Archive::Zip::AZ_OK or die 'write error';
  warn "par_mini done\n";

} # end subroutine ACTION_par_mini definition
########################################################################

=item par_seed

=cut

sub ACTION_par_seed {
  my $self = shift;

  File::Path::mkpath($self->par_deps_dir);

  my $parfile = $self->par_seed;
  my @our_mods = map({s#^lib/+##; $_} keys(%{$self->find_pm_files}));

  if($self->up_to_date([map({'lib/' . $_} @our_mods)], $parfile)) {
    warn "$parfile is up to date\n";
    return;
  }

  $self->depends_on('code');
  $self->depends_on('datadir');

  # TODO get the deplist from cache or scandeps on the bootstrap file?
  my @deps = $self->scan_deps(
    modules => [qw(dtRdr::0 warnings strict File::Spec Cwd Config version)],
    files => [qw(client/build_info/par_bootstrap.pl)],
  );
  0 and warn join("\n  ", "got deps:", @deps);

  # build it by including all of blib/lib
  my @command = (
    $self->which_pp,
    '-p', # plain par
    '-o', $parfile,
    qw(-z 9),
    '-n', # no scanning, no compiling, no executing
    '-a',  $self->datadir . ';data',
    qw(-I blib/lib),
    '-B', # need early core stuff in here
    map({('-M', $_)} @deps, @our_mods),
    'client/build_info/dotReader.pl'
  );

  warn "pp for $parfile\n";
  0 and warn "# @command\n";
  require Config_m if($^O eq 'MSWin32');
  local $ENV{PERL5LIB} = join($Config{path_sep}, 'blib/lib',
    split($Config{path_sep}, $ENV{PERL5LIB} || ''));
  system(@command) and die "$! $^E $?";
  warn "par_seed done\n";

} # end subroutine ACTION_par_seed definition
########################################################################

=item par_pl

Build the blib/dotReader.pl file

=cut

sub ACTION_par_pl {
  my $self = shift;

  my ($boot, $app_pl) = map(
    { open(my $fh, '<', $_) or die "cannot open $_"; local $/; <$fh> }
    'client/build_info/par_bootstrap.pl', 'client/app.pl'
  );

  my $prelude_class = 'dtRdr::par_bootstrap';
  my $import_deps = "BEGIN {$prelude_class->post_bootstrap;}\n";
  $app_pl =~ s/^#### PAR_LOADS_DEPS_HERE.*$/$import_deps/m or die;

  my ($wx_par, $deps_par, $core_par) =
    map({$self->par_dep_file($_)} qw(wx deps core));

  # TODO get names for deps.par, etc
  my $prelude = <<"  ---";
    BEGIN {
      \$${prelude_class}::shared_par = '$wx_par';
      \$${prelude_class}::core_par = '$core_par';
      \$${prelude_class}::deps_par = '$deps_par';
    }
    BEGIN {
      package $prelude_class;
      \n$boot
    }
  ---

  my $main_pl = $self->parmain_pl;
  open(my $fh, '>', $main_pl) or die "cannot write $main_pl";
  print $fh "$prelude\n$app_pl";
  close($fh) or die "write $main_pl failed";
} # end subroutine ACTION_par_pl definition
########################################################################

=item par_wx

=cut

sub ACTION_par_wx {
  my $self = shift;

  $self->depends_on('par_seed');

  my $parfile = $self->par_wx;
  if(-e $parfile) { # if you have it, I'll say that's enough
    warn "$parfile is up to date\n";
    return;
  }

  # get all of the wx mods and libs
  #   compile to get -M list
  my @deps = $self->scan_deps(
    string => qq(use Wx qw(:everything :allclasses);),
  );
  0 and warn join("\n  ", "got deps:", @deps);

  use Config;

  $ENV{$Config{ldlibpthname}} = join($Config{path_sep},
    qw(/usr/lib /usr/local/lib)) if($^O eq 'linux');

  my @command = (
    $self->which_pp,
    '-o', $parfile,
    qw(-z 9),
    '-p', # plain par
    '-n', # no scanning, no compiling, no executing
    map({('-M', $_)} @deps),
    map({('-l', $_)} $self->external_libs),
    '-e', ';'
  );
  warn "pp for $parfile\n";
  0 and warn "# @command\n";
  system(@command) and die "$!";
  warn "par_wx done\n";
  $self->update_dep_version('wx');
} # end subroutine ACTION_par_wx definition
########################################################################

=item par_deps

Bundle all of the non-core, non-wx dependencies.

=cut

sub ACTION_par_deps {
  my $self = shift;

  my @req = keys(%{$self->requires});
  0 and warn join("\n  ", 'requires', @req);

  # TODO put those in a file somewhere for caching?
  # TODO versioning in client/build_info/par_versions/deps-v0.0.10.yml?
  $self->depends_on('par_wx');

  my $parfile = $self->par_deps;
  if(-e $parfile) { # if you have it, I'll say that's enough (for now)
    warn "$parfile is up to date\n";
    return;
  }

  my $seed_par = $self->par_seed;
  my $wx_par = $self->par_wx;

  # to compile a list or not to compile a list?
  my @deps = $self->scan_deps(string => $self->dependency_hints);

  my @modlist = do {my %s; map({$s{$_} ? () : ($s{$_} = $_)} @deps, @req)};
  0 and warn join("\n  ", "modlist", @modlist);

  my @command = (
    $self->which_pp,
    '-o', $parfile,
    qw(-z 9),
    '-p', # plain par
    #'-n', # allow scanning (for now)
    map({('-M', $_)} @modlist),
    '-X', $seed_par,
    '-X', $wx_par,
    '-e', ';'
  );
  warn "pp for $parfile\n";
  0 and warn "# @command\n";
  system(@command) and die "$!";
  warn "par_deps done\n";
  $self->update_dep_version('deps');
} # end subroutine ACTION_par_deps definition
########################################################################

=item par_core


=cut

sub ACTION_par_core {
  my $self = shift;

  $self->depends_on('par_deps');
  my $parfile = $self->par_core;
  if(-e $parfile) { # if you have it, I'll say that's enough (for now)
    warn "$parfile is up to date\n";
    return;
  }

  my $seed_par = $self->par_seed;
  my $wx_par = $self->par_wx;
  my $deps_par = $self->par_deps;

  my @our_mods = map({s#^lib/+##; $_} keys(%{$self->find_pm_files}));
  my @req = keys(%{$self->requires});

  # get the deplist from cache or scandeps on allmods+the hints file
  my @deps = $self->scan_deps(
    files => [@our_mods],
    modules => [@req],
    string => $self->dependency_hints,
  );
  0 and warn join("\n  ", 'deps are', @deps, '');

  my @command = (
    $self->which_pp,
    '-o', $parfile,
    qw(-z 9),
    '-I', 'blib/lib',
    '-p', # plain par
    #'-n', # allow scanning (for now)
    map({('-M', $_)} @deps),
    '-X', $seed_par,
    '-X', $wx_par,
    '-X', $deps_par,
    '-B', # bundle core modules
    '-e', ';'
  );
  warn "pp for $parfile\n";
  0 and warn "# @command\n";
  local $ENV{PERL5LIB} = join($Config{path_sep}, 'blib/lib',
    split($Config{path_sep}, $ENV{PERL5LIB} || ''));
  system(@command) and die "$!";
  warn "par_core done\n";
  $self->update_dep_version('core');
} # end subroutine ACTION_par_core definition
########################################################################

=item repar

Build and repackage the 'data/' directory for the par.

  ./Build repar

  ./Build repar nodata

=cut

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

  require Archive::Zip;

  my $filename = $self->binfilename;

  my $src_dir = $self->datadir;
  (-e $src_dir) or
    die "you need to unset NO_DATA or manually build $src_dir";

  my $zip = Archive::Zip->new();
  $zip->read($filename) == Archive::Zip::AZ_OK or
    die("'$filename' is not a valid zip file.");
  $zip->updateTree($src_dir, 'data', sub {-f });
  $zip->overwrite( $filename ) == Archive::Zip::AZ_OK or die 'write error';
  undef($zip);

  rename($filename, "$filename.par") or die;
  system($self->which_pp, '-o', $filename, "$filename.par") and die;
  unlink("$filename.par") or warn "cannot remove '$filename.par' $!";
  warn "ok\n";
} # end subroutine ACTION_repar definition
########################################################################

=item datadir

Build the 'data/' directory that goes inside the par in blib/pardata/.

=cut

sub ACTION_datadir {
  my $self = shift;

  # TODO up_to_date check?
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


sub ACTION_appbundle {
  my $self = shift;

  $self->depends_on('datadir');
  local $self->{args}{deps} = 1;
  my $libs = $self->find_pm_files;
  local $self->{properties}{mm_also_scan} = [keys(%$libs)];
  local $self->{properties}{mm_add} = [
    $self->additional_deps,
    map({s#/+#::#g; s/\.pm//; $_} grep({m/\.pm$/}
      $self->scan_deps(string => $self->dependency_hints)
    )),
  ];
  my $mm = # TODO some way to do that with SUPER::
    Module::Build::Plugins::MacBundle::ACTION_appbundle($self, @_);

  # XXX ugh, bit of thrashing-about involved here
  # copy
  my $dest = $self->binfilename;
  #if(-e $dest) {
  #  File::Path::rmtree($dest) or die $!;
  #}
  unless(-d $dest) {
    File::Path::mkpath($dest) or die "$dest $!";
  }
  warn "copy to $dest";
  system('rsync', '-a', '--delete',
    $mm->built_dir . '/', $dest . '/') and die;

  # datadir
  system('rsync', '-a', '--delete',
    $self->datadir . '/', "$dest/Contents/Resources/data/") and die;

} # end subroutine ACTION_appbundle definition
########################################################################

=item parmanifest

Extract the MANIFEST file from the current par (saves compilation time
on the next BUILD par)

=cut

sub ACTION_parmanifest {
  my $self = shift;

  my $filename = $self->binfilename;
  my $parmanifest = $self->parmanifest;
  open(my $fh, '>', $parmanifest) or
    die "cannot write to $parmanifest $!";
  print $fh $self->grab_manifest($filename);
} # end subroutine ACTION_parmanifest definition
########################################################################

=item starter_data

Assemble a default config, library, and some free books in
"binary_build/dotreader-data/"

=cut

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
  # actually, need to get this out of the picture
  my @books = (
    map({'books/default/' . $_}
      map({$_ . '.jar'}
        qw(
          dotReader_beta_QSG
          Alienation_Victim
          publication_556
          rebel-w-o-car
          seventy_five_times
          Reflections
          dpp_reader
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

  # standard plugins
  my @plugins = qw(example_plugins/InfoButton/);
  require File::Path;
  my $pdir = $data_dir . 'plugins/';
  if(-e $pdir) {
    my $dirname = $pdir;
    $dirname =~ s#/$##; # $%^&* windows!
    File::Path::rmtree($dirname) or die "$dirname -- $!";
  }
  File::Path::mkpath($pdir) or die "$pdir -- $!";
  foreach my $dir (@plugins) {
    $dir =~ s#/*$#/#;
    my $mfile = $dir . 'MANIFEST';
    (-e $mfile) or die "cannot add plugin $dir without $mfile";
    my @manifest = do {
      open(my $fh, '<', $mfile) or die $!;
      map({chomp; $_} <$fh>);
    };
    foreach my $file (@manifest) {
      my $src = $dir . '/' . $file;
      $self->copy_if_modified(
        from => $src,
        to => $pdir . '/' . $file,
        verbose => 1,
      );
    }
    # and ship the manifest file
    my $mname = $dir;
    $mname =~ s#/*$##;
    $mname = $pdir . '/' . File::Basename::basename($mname) . '.MANIFEST';
    warn "create $mname";
    $self->copy_if_modified(
      from => $mfile,
      to => $mname,
    );
  }

  # TODO add some annotation data, bells, whistles, etc

} # end subroutine ACTION_starter_data definition
########################################################################

=item binary

Builds the binary and starter data for the current platform.

=cut

sub ACTION_binary {
  my $self = shift;
  my %args = $self->_my_args;
  $self->depends_on( ($^O eq 'darwin') ?  'appbundle' : 'par' );
  $args{bare} or $self->depends_on('starter_data');
} # end subroutine ACTION_binary definition
########################################################################

=item binary_package

Build the binary, starter data, and wrap it up.

Also takes a --bare argument

=cut

sub ACTION_binary_package {
  my $self = shift;
  $self->depends_on('binary');
  my %choice = map({$_ => $_} qw(darwin MSWin32));
  my $method = 'binary_package_' . ($choice{$^O} || 'linux');
  $self->$method;
} # end subroutine ACTION_binary_package definition
########################################################################

=back

=cut

########################################################################
# NO MORE ACTIONS
########################################################################

=head1 Helpers and Such

=head2 binary_package_name

Assembles exception, platform, modifiers, version, and version bump
values into a name (without .extension)

  my $packname = $self->binary_package_name;

=cut

sub binary_package_name {
  my $self = shift;

  my %args = $self->_my_args;

  my %choice = (
    darwin => 'mac',
    MSWin32 => 'win32',
  );
  my $platform = $choice{$^O} || $^O;
  my @special = (
    ($args{mini} ? 'mini' : ()),
    ($args{bare} ? 'bare' : ()),
  );
  my @extra; # ppc, dev, etc
  my $bump; # e.g. pre
  my $name = join('-',
    lc($self->dist_name),
    @special,
    $platform,
    @extra,
    ($args{'version-force'} ?
      $args{'version-force'} :
      $self->dist_version
    ),
    ($args{'version-bump'} ? $args{'version-bump'} : ()),
  );
  return($name);
} # end subroutine binary_package_name definition
########################################################################

=head2 binary_package_linux

Linux and others.

  $self->binary_package_linux;

=cut

sub binary_package_linux {
  my $self = shift;

  my $packname = $self->binary_package_name;
  warn "package name $packname";

  require File::Path;
  if(-e $packname) {
    File::Path::rmtree($packname);
  }
  mkdir($packname) or die "cannot create directory '$packname'";
  $self->copy_package_files($packname);
  my $tarball = $self->distfilename;
  if(-e $tarball) {
    unlink($tarball) or die "cannot delete $tarball -- $!";
  }
  system('tar', '-czhvf', $tarball, $packname) and
    die "tarball failed $!";
  # cleanup
  File::Path::rmtree($packname);
} # end subroutine binary_package_linux definition
########################################################################

=head2 binary_package_darwin

  $self->binary_package_darwin;

=cut

sub binary_package_darwin {
  my $self = shift;

  my %args = $self->_my_args;
  my $packname = $self->binary_package_name;

  warn "package name $packname";
  my $size = 0;
  {
    require IPC::Run;
    my ($in, $out, $err);
    IPC::Run::run(['du', '-ks', $self->binfilename,
      ($args{bare} ? () : $self->starter_data_dir)],
    \$in, \$out, \$err) or die "failed $err";
    $size += $_ for(map({s/\s.*//; $_} split(/\n/, $out)));
    $size = int($size / 1024) + 5;
  }

  # XXX this is pretty slow at 45MB
  my $tmpdmg = '/tmp/tmp.dmg';
  unlink($tmpdmg);
  warn "create dmg at $size MB\n";
  system(qw(hdiutil create -size), $size . 'm',
    qw(-fs HFS+ -volname), $packname, $tmpdmg) and die $!;
  # TODO check for failed umount
  system(qw(hdiutil attach), $tmpdmg) and die $!;

  warn "copy to image\n";
  system('rsync', '-a', $self->binfilename, '/Volumes/' . $packname)
    and die "$!";
  unless($args{bare}) {
    system('rsync', '-a',
      $self->starter_data_dir, '/Volumes/' . $packname) and die "$!";
  }

  # only on recent osx
  system(qw(hdiutil detach), '/Volumes/' . $packname) and die $!;

  my $outdmg = $self->distfilename;
  unlink($outdmg);
  warn "convert dmg\n";
  system(qw(hdiutil convert), $tmpdmg, qw(-format UDZO), '-o', $outdmg)
    and die $!;


} # end subroutine binary_package_darwin definition
########################################################################

=head2 binary_package_MSWin32

  $self->binary_package_MSWin32;

=cut

sub binary_package_MSWin32 {
  my $self = shift;

  my $packname = $self->binary_package_name;
  warn "package name $packname";

  require File::Path;
  if(-e $packname) {
    File::Path::rmtree($packname);
  }
  mkdir($packname) or die "cannot create directory '$packname'";
  $self->copy_package_files($packname);
  my $zipfile = $self->distfilename;
  if(-e $zipfile) {
    unlink($zipfile) or die "cannot delete $zipfile -- $!";
  }
  my $zipname = 'dotreader.zip';
  if(-e $zipname) {
    unlink($zipname) or die "cannot delete $zipname -- $!";
  }
  system('zip', '-r', $zipname, $packname) and die $!;
  require File::Which;
  my $unzipsfx = File::Which::which('unzipsfx');
  $unzipsfx or die "you need unzipsfx";
  my $zip;
  foreach my $file ($unzipsfx, $zipname) {
    open(my $fh, '<', $file) or die "$file $!";
    binmode($fh);
    local $/;
    $zip .= <$fh>;
  }
  {
    open(my $ofh, '>', $self->distfilename) or die $!;
    binmode($ofh);
    print $ofh $zip;
    close($ofh) or die $!;
  }

  system('zip', '-A', $self->distfilename);
  # cleanup
  File::Path::rmtree($packname);
} # end subroutine binary_package_MSWin32 definition
########################################################################

=head2 copy_package_files

  $self->copy_package_files($dir); # useful for mac too

=cut

sub copy_package_files {
  my $self = shift;
  my ($dir) = @_;

  my %args = $self->_my_args;

  require File::NCopy;
  my $copy = sub {
    my ($file) = @_;
    File::NCopy->new(
      recursive      => 1,
      #set_permission => sub {chmod(0700, $_[1]) or die $!},
      )->copy($file, $dir . '/') or die "copy failed $!";
    };
  $copy->($self->binfilename);
  if($args{mini}) {
    # don't ship the cache dir
    my $depdir = "$dir/dotreader-deps";
    mkdir($depdir) or die;
    $depdir .= '/';
    for(map({$self->$_} qw(par_wx par_core par_deps))) {
      File::NCopy->new->copy($_, $depdir) or die;
    }
  }
  $args{bare} or $copy->($self->starter_data_dir);
} # end subroutine copy_package_files definition
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

=head2 run_binary

Run the binary, returns stdout and stderr strings, replaces the
first_time file (if it didn't crash.)

  my ($out, $err) = $self->run_binary;

=cut

sub run_binary {
  my $self = shift;

  # build it
  $self->depends_on('binary');
  $self->depends_on('starter_data');

  my $ft_file = $self->starter_data_dir . '/first_time';
  (-e $ft_file) or die "first_time file did not get created";

  my $file = $self->binfilename_sys;
  warn "launch $file\n";
  require IPC::Run;
  my ($out, $err);
  IPC::Run::run([$file], \*STDIN, \$out, \$err) # TODO tee stderr
    or die "bad exit status $! $? ($err)";

  # check
  (-e $ft_file) and die "first_time file did not get deleted";
  open(my $fh, '>', $ft_file); # putback

  return($out, $err)
} # end subroutine run_binary definition
########################################################################

sub binfilename {
  my $self = shift;

  my %args = $self->_my_args;
  return($self->binary_build_dir . '/dotReader.app')
    if($^O eq 'darwin');
  return(
    $self->binary_build_dir .
      '/dotReader' .
      ($args{mini} ? '-mini' : '') .
      ($^O eq 'MSWin32' ? '.exe' : '')
  );
}

# slight difference
sub binfilename_sys {
  my $self = shift;
  return( 
    $self->binfilename . 
    (($^O eq 'darwin') ? '/Contents/MacOS/dotReader' : '')
  );
}

# the distribution file (depends on current options)
sub distfilename {
  my $self = shift;
  my $packname =
    $self->binary_build_dir . '/' .
    $self->binary_package_name . $self->distfile_extension;
  return($packname);
}
sub distfile_extension {
  my $self = shift;
  my %choice = (
    darwin => '.dmg',
    MSWin32 => '.exe',
  );
  return($choice{$^O} || '.tar.gz');
}

sub starter_data_dir {
  my $self = shift;
  return($self->binary_build_dir . '/dotreader-data');
}
use constant {
  datadir => 'blib/pardata',
  clientdata => 'client/data',
  binary_build_dir => 'binary_build',
  parmanifest   => 'blib/parmanifest',
  parmain_pl    => 'blib/dotReader.pl',
};
sub par_deps_dir {
  my $self = shift;
  return($self->binary_build_dir . '/dotreader-deps');
}
sub par_seed { shift->binary_build_dir . '/seed.par', };
sub par_mini {
  my $self = shift;
  return($self->binary_build_dir . '/' .
    join('-',
      'dotReader-mini',
      $self->dist_version,
      $self->short_archname,
      $Config{version}
    ) .'.par');
}
foreach my $tag (qw(wx deps core)) {
  my $sub = sub {
    my $self = shift;
    $self->par_deps_dir . '/' . $self->par_dep_file($tag)
  };
  my $subname = 'par_' . $tag;
  no strict 'refs';
  *{$subname} = $sub;
}

sub version_file {
  my $self = shift;
  my $tag = shift;
  use Config;
  my $file = "client/build_info/deplist.$tag-" .
    $self->short_archname . "-$Config{version}.yml";
}

=head2 par_dep_file

Returns the basename for the par dependency file.

  $file = $self->par_dep_file($tag);

=cut

sub par_dep_file {
  my $self = shift;
  my ($tag) = @_;
  my $version = $self->dep_version($tag);
  return(
    join('-', $tag, $version, $self->short_archname, $Config{version}) .
    '.par'
  );
} # end subroutine par_dep_file definition
########################################################################
use constant {
  short_archname => sub {
    my $n = shift;
    $n =~ s/-(.*)$//;
    return($n . '.' . join('',
      map({m/^(.*\d+)/ ? $1 : substr($_, 0, 1)} split(/-/, $1))
      ));
  }->($Config{archname})
};

=head2 update_dep_version

Returns a new version number for the dependency tag or undef if it has
not changed.

  $version = $self->update_dep_version($tag);

=cut

sub update_dep_version {
  my $self = shift;
  my ($tag) = @_;

  my $checkfile = $self->deplist_file($tag);
  # read the existing data
  my ($version, $old_deps);
  if(open(my $fh, '<', $checkfile)) {
    chomp($version = <$fh>);
    local $/;
    $old_deps = <$fh>;
    $old_deps =~ s/\n+$//;
  }
  # get the manifest from the archive
  my $depmethod = 'par_' . $tag;
  my $archive = $self->$depmethod;
  my $new_deps;
  {
    my $man = $self->grab_manifest($archive);
    my @mods = split(/\n/, $man);
    if($^O eq 'MSWin32') { # grr, scandeps problem?
      foreach my $mod (@mods) {
        if($mod =~ s#^lib/+([a-z]:/)#$1#i) {
          warn "mod fix $mod\n";
          my $kill_inc = join("|", map({quotemeta($_)}
            sort({length($b) <=> length($a)} @INC))
          );
          warn "kill inc $kill_inc";
          $mod =~ s/^(?:$kill_inc)/lib\//i;
        }
      }
    }
    my @deps = grep(
      {
        $_ !~ m#^auto/# and
        $_ !~ m#^unicore/#
      }
      map({chomp;s#^lib/+##;$_} 
        grep({m#^lib/# and m/\.pm$/} @mods)
      )
    );
    for(@deps) { s#/+#::#g; s/\.pm$//;}

    warn "get versions\n";
    my %depv;
    foreach my $mod (@deps) {
      my $v = Module::Build::ModuleInfo->new_from_module(
        $mod, collect_pod => 0
      );
      defined($v) or die "cannot create ModuleInfo for $mod";
      $v = $v->version;
      $v = $v->stringify if(defined($v) and ref($v));
      $depv{$mod} = defined($v) ? $v : '~';
    }
    $new_deps = join("\n", map({"$_ $depv{$_}"} sort(keys(%depv))));
  }
  0 and warn "new deps:\n$new_deps\n";
  return if($new_deps eq (defined($old_deps) ? $old_deps : ''));
  my $new_version = $self->dist_version;
  if($new_version eq ($version || '')) {
    die "dependencies for '$tag', changed, dist_version didn't";
  }
  warn "$tag version changed to $new_version\n";
  # save the data
  open(my $fh, '>', $checkfile) or die "cannot write $checkfile";
  print $fh join("\n", $new_version, $new_deps, '');
  close($fh) or die "write $checkfile failed";
  # rename the archive
  rename($archive, $self->$depmethod) or die "cannot rename $archive";
  # and return the new version
  return($new_version);
} # end subroutine update_dep_version definition
########################################################################

=head2 dep_version

Returns the current version number for the dependency tag.  This will be
the dotReader version number at which it was last changed.

  $version = $self->dep_version($tag);

=cut

sub dep_version {
  my $self = shift;
  my ($tag) = @_;

  my $version;

  my $checkfile = $self->deplist_file($tag);
  if(-e $checkfile) {
    open(my $fh, '<', $checkfile);
    my $v = <$fh>;
    chomp($v);
    length($v) or die "bad $checkfile";
    $v =~ m/^v\d+\.\d+\.\d+$/ or die "bad version '$v' in $checkfile";
    $version = $v;
  }
  return($version || $self->dist_version);
} # end subroutine dep_version definition
########################################################################

=head2 deplist_file

  my $checkfile = $self->deplist_file($tag);

=cut

sub deplist_file {
  my $self = shift;
  my ($tag) = @_;

  my $checkfile = 'client/build_info/' . 'deplist.' .
    join('-', $tag, $self->short_archname, $Config{version});
} # end subroutine deplist_file definition
########################################################################

sub _my_args {
  my $self = shift;

  my %args = $self->args;
  # TODO index this by the calling subroutine?
  my @bin_opts = qw(
    clean
    dev
    nolink
    bare
    mini
  );
  foreach my $opt (@bin_opts) {
    $args{$opt} = 1 if(exists($args{$opt}));
  }
  return(%args);
}

# for par (TODO put this elsewhere)
sub additional_deps {
  qw(
    dtRdr::Library::SQLLibrary
    Log::Log4perl::Appender::File
    Log::Log4perl::Appender::Screen
  );
}

=head2 dependency_hints

  my $string = $self->dependency_hints;

=cut

sub dependency_hints {
  my $self = shift;
  open(my $fh, '<', 'client/build_info/runtime_deps.pm') or die;
  local $/ = undef;
  return(<$fh>);
} # end subroutine dependency_hints definition
########################################################################

=head2 external_libs

  @libs = $self->external_libs;

=cut

sub external_libs {
  my $self = shift;

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
      ),
      # I'm really getting tired of trying to bundle mozilla
      (0 ? qw(
        gtkembedmoz
        xpcom
        nspr4
        libmozjs
        jsj
        libmozz
      ) : () ),
    );
    push(@other_dll, qw(
      /usr/lib/libstdc++.so.6
      /usr/lib/libexpat.so.1
    ));
  }
  elsif($^O eq 'MSWin32') {
    @wxlibs = map({'C:/Perl/site/lib/auto/Wx/' . $_}
      qw(
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
  return(@wxlibs, @other_dll);
} # end subroutine external_libs definition
########################################################################

=head2 which_pp

The pp command

=cut

sub which_pp {
  my $self = shift;
  return(($^O eq 'MSWin32') ? ($self->perl, 'c:/perl/bin/pp') : ('pp'));
} # end subroutine which_pp definition
########################################################################

=head2 grab_manifest

  $string = $self->grab_manifest($zipfile);

=cut

sub grab_manifest {
  my $self = shift;
  my ($filename) = @_;

  require Archive::Zip;
  my $zip = Archive::Zip->new;
  $zip->read($filename);
  my $member = $zip->memberNamed('MANIFEST');
  return($zip->contents($member));
} # end subroutine grab_manifest definition
########################################################################

# TODO put this in dtRdr.pm?
use constant {release_file => 'dotreader_release'};
sub write_release_file {
  my $self = shift;
  my ($location) = @_;

  # let this get a different value from somewhere
  my %args = $self->_my_args;
  my $release = $args{'release'};
  if($release) {
    if($release eq 'T') { # don't know if I'll use this, but here
      $release = svn_tag() or die "not in a tag";
    }
    elsif($release eq 'V') {
      $release = $self->dist_version;
    }
  }
  else {
    $release = 'pre-release';
  }

  $release .= ' (' . svn_rev() . ') built ' . scalar(localtime);

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
    eval {IPC::Run::run(\@command, \$in, \$out, \$err)}
      or return("notsvn-" . time());
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
  return('svn' . $rev);
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

=head2 scan_deps

  $self->scan_deps(
    modules => \@mods,
    files => \@files,
    string => \$string
  );

=cut

sub scan_deps {
  my $self = shift;
  my %args = @_;

  require Module::ScanDeps;
  require File::Temp;
  require File::Spec;
  require Config;
  my ($fh, $tmpfile) = File::Temp::tempfile('dtRdrBuilder-XXXXXXXX',
    UNLINK => 1, DIR => File::Spec->tmpdir,
  );
  0 and warn "writing to $tmpfile";
  print $fh "BEGIN {\n";

  foreach my $mod (@{$args{modules} || []}) {
    print $fh qq(require $mod;\n);
  }
  foreach my $file (@{$args{files} || []}) {
    print $fh qq(require("$file");\n);
  }
  defined($args{string}) and print $fh $args{string}, "\n";

  print $fh "} # close begin\n1;\n";
  close($fh) or die "out of space?";

  local $ENV{PERL5LIB} = join($Config{path_sep}, 'blib/lib',
    split($Config{path_sep}, $ENV{PERL5LIB} || ''));
  my $hash_ref = Module::ScanDeps::scan_deps_runtime(
    files => [$tmpfile], compile => 1, recurse => 0,
  );
  #unlink($tmpfile) or die "cannot remove $tmpfile";
  my @files =
    grep({$_ !~ m/\.$Config{dlext}$/}
    grep({$_ !~ m/\.bs$/}
      keys(%$hash_ref)
    ));
  return(@files);
} # end subroutine scan_deps definition
########################################################################

=head1 Overridden Methods

=head2 find_pm_files

Overridden to eliminate platform-specific deps.

Also, fixes QDOS problems.

  $self->find_pm_files;

=cut

sub find_pm_files {
  my $self = shift;
  my $files = $self->SUPER::find_pm_files;

  if($^O eq 'MSWin32') {
    %$files = map({my $v = $files->{$_}; s#\\#/#g; ($_ => $v)}
      keys(%$files)
    );
  }

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

sub ACTION_build {
  my $self = shift;
  $self->depends_on('books'); # XXX ick -- needed for disttest to pass
  $self->SUPER::ACTION_build;
} # end subroutine ACTION_build definition
########################################################################

sub ACTION_manifest {
  my $self = shift;
  $self->SUPER::ACTION_manifest;
  open(my $afh, '<', 'MANIFEST.add') or die;
  open(my $mfh, '>>', 'MANIFEST') or die;
  print $mfh join('', <$afh>);
} # end subroutine ACTION_manifest definition
########################################################################

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
