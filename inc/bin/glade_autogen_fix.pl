#!/usr/bin/perl

# a rewriter and other silly stuff

use strict;
use warnings;

my $ifh = \*STDIN;
my $filename;
if(@ARGV) { # unfiltered version
  $filename = shift(@ARGV);
  open(my $f, $filename);
  $ifh = $f;
}

my $content='';
{
  local $/;
  $content=<$ifh>;
}

my $ofh = \*STDOUT;
if($filename) {
  open(my $f, '>', $filename);
  $ofh = $f;
}


$content =~ s/use Wx::HtmlWindow/use Wx::Html/ig;
$content =~ s/menu->AppendMenu/menu->Append/ig;
$content =~ s/(Wx::Bitmap->new\([^)]+\))/&fix_bitmaps($1)/ige;

# glade wants to force the layout to elsewhere, which is at least
# non-fun, so we swap-in custom subclasses for some widgets here
my @swap_map = (
  [qw(note_viewer_pane Wx::Panel dtRdr::GUI::Wx::NoteViewer)],
  [qw(search_pane Wx::Panel dtRdr::GUI::Wx::SearchPane)],
);

$content = class_swap($content, $_) for(@swap_map);
# try it the quick way
$content = quick_var_decl($content, 'wxglade_tmp_menu_sub');
# all that compiling just to declare the same variable every time?
# turn this back on if they start coming out of the woodwork:
# $content = check_var_decl($content);

$content =~ s/\n*$/\n/;

print $ofh $content;

#-------------------------------------------------------------------------------

sub fix_bitmaps {
  my ($path) = @_;
  $path =~ s/\\{2}/\//ig;
  my $pref_path = "data/gui_default";
  $path =~ s/(")(?:DATA_PATH|[^"]*$pref_path)/dtRdr->data_dir.$1gui_default/ig;
  return $path;  
}

# glade won't allow a simple subclass substitution without generating a
# whole new file.  If we let it do this, we would have to swap-out that
# file's baseclass and other silly junk.  It's only s/$core/$mine/, so
# let's not over-complicate it, ok.
sub class_swap {
  my ($content, $map) = @_;

  my @lines = split(/\n/, $content);
  my @out;
  my ($att, $core, $mine) = @$map;
  foreach my $line (@lines) {
    if($line =~ s/(->\{$att\} = )$core(->new\()/$1$mine$2/) {
      warn "drop-in $att =~ s/$core/$mine/\n";
    }
    push(@out, $line);
  }
  return(join("\n", @out));
}

sub quick_var_decl {
  my ($content, @vars) = @_;
  my @lines = split(/\n/, $content);
  my @out;
  foreach my $line (@lines) {
    for(my $i = 0; $i < @vars; $i++) {
      my $var = $vars[$i];
      if($line =~ s/^(\s*)(\$$var)\b/$1my $2/) {
        splice(@vars, $i, 1);
        $i--;
      }
    }
    push(@out, $line);
  }
  return(join("\n", @out));
}
sub check_var_decl {
  my ($content) = @_;
  unless(-e 'client') {
    warn "this won't work for you -- hope you don't need it";
    return($content);
  }
  require IPC::Run;

  # PPI might make this cleaner

  # make a fake tree of modules and also delete the glade stubs
  # anybody else hate glade yet
  fake_tree('lib/dtRdr', 'client/dtRdr');

  my ($in, $out, $err);
  # run perl, run
  my $v = IPC::Run::run(
    [$^X, '-MO=Deparse', '-Iclient', '-e', "$content"],
    \$in, \$out, \$err
    ); 
  unless($v) {
    $err =~ m/Global symbol "([^"]+)" .* at .* line (\d+)/ or
      die "can't deal with:\n\n$err\n ";
    my $var = $1;
    my $line = $2;
    warn "declaring '$var'";
    $var =~ s/^\$// or die;
    { # break down and build up again
      my @lines = split(/\r?\n/, $content);
      $lines[$line-1] =~ s/\$$var( *=)/my \$$var$1/ or
        die "eek ", $lines[$line-1];
      $content = join("\n", @lines, '');
    }
    return(check_var_decl($content));
  }
  rmtree(["client/dtRdr"]); # smack glade with a wibble
  return($content);
}

use File::Find;
use File::Path;
use File::Basename;
sub fake_tree {
  my ($from_dir, $dest_dir) = @_;
  my @found;
  find(sub {
    ($_ =~ m/\.pm$/) or return();
    push(@found, $File::Find::name);
  }, $from_dir);
  foreach my $file (@found) {
    #warn "found $file";
    my $dir = dirname($file);
    my $fname = basename($file);
    $dir =~ s/^lib/client/ or die "oops";
    mkpath([$dir]);
    open(my $fh, '>', "$dir/$fname") or die $!;
    my $package = $file;
    $package =~ s/lib//;
    $package =~ s/\.pm//;
    $package =~ s/[\/\\]+/::/g;
    print $fh "package $package;\nsub new {};\n1;\n";
  }
}

# vim:ts=2:sw=2:et:sta
