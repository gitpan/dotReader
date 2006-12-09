use strict;
use warnings;
use inc::dtRdrBuilder;
my $build_class = 'inc::dtRdrBuilder';

my $builder = $build_class->new(
  dist_name         => 'dotReader',
  # this would be 'gpl' when we release
  license             => 'gpl',
  dist_version_from   => 'lib/dtRdr.pm',
  dist_author         => 'OSoft Inc.',
  recursive_test_files => 1,
  testfile_types       => {
    'gui' => 'gt',
  },
  build_requires => { # should be test_requires, but not in 0.28
    'IPC::Run' => 0,
  },
  main_pl_file => 'client/app.pl',
  requires => {
    'Test::More'               => 0.62,
    'Archive::Zip'             => 0,
    'Archive::Zip::MemberRead' => 0,
    'Class::Accessor'          => '0.25',
    'Class::Accessor::Classy'  => '0.001001',
    # 'Class::Trait'             => '0.20',
    'DBD::SQLite'              => 0, # 1.12 ??
    'DBI'                      => 0,
    'File::NCopy'              => 0,
    'Module::Finder'           => '0.001001',
    'Module::Pluggable'        => '2.96',
    'Wx'                       => '0.26',
    'Wx::Event'                => 0,
    'Wx::Html'                 => 0,
    'XML::Parser::Expat'       => 0,
    'Method::Alias'            => 0,
    'Data::GUID'               => 0,
    'Log::Log4perl'            => 1.0,
    'XML::Twig'                => 3.22,
    'YAML::Syck'               => 0.67,
    ################################################################
    # Windows prereqs
    ( $^O eq 'MSWin32' ? (
      'Wx::ActiveX::IE' => 0
      ) : ()),
    ################################################################
    # linux prereqs
    ( $^O eq 'linux' ? (
      'Wx::Mozilla' => 0.05
      ) : ()),
    ################################################################
    # darwin prereqs
    ( $^O eq 'darwin' ? (
      'Wx::WebKit' => 0.04
      ) : ()),
    ################################################################
  }, # end requires
  build_requires => {
    'PAR'             => 0,
    'Devel::TraceUse' => 0,
  },
  add_to_cleanup      => [ qw(
    META.yml
    binary_build
    )],
);

$builder->create_build_script();

# vim:ts=2:sw=2:et:sta
