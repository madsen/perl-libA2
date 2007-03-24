#! /usr/bin/perl
#---------------------------------------------------------------------
# $Id$
# Copyright 2006 Christopher J. Madsen
#
# Build.PL for LibA2
#---------------------------------------------------------------------

use FindBin;
use lib $FindBin::Bin; # Make sure we're using A2_Build from our distribution

use A2_Build;          # Our customized version of Module::Build

my $build = A2_Build->new(
  dist_name          => 'LibA2',
  dist_version       => '0.08',
  dist_author        => 'Christopher J. Madsen <perl@cjmweb.net>',
  dist_abstract      => 'Apple II emulator & file utilities',
  license            => 'perl',
  requires           => {
    perl               => '5.6.0',
    'Getopt::Long'     => '2.10',
    'IO::File'         => 0,
    'POSIX'            => 0,
  },
  recommends         => {
    'Term::ReadLine::Perl' => 0,
  },
  build_requires     => { FindBin => 0, 'Module::Build' => 0 },
  dynamic_config     => 1,      # We have the --no-scripts option
  get_options        => { 'no-scripts' => undef },
  add_to_cleanup     => [ 't/tmpdir' ],
  create_makefile_pl => 'passthrough',
  meta_merge         => { no_index => { file => ['A2_Build.pm'] }},
);

chdir $FindBin::Bin or die "Unable to cd to $FindBin::Bin: $!\n";
my @scripts;

if ($build->args('no-scripts')) {
  $build->dispatch('clean');   # The scripts might already be in blib/
} else {
  @scripts = sort grep { not /~$/ } glob "bin/*";
}

$build->script_files(\@scripts);

$build->create_build_script;

if (@scripts) {
  print "The following scripts will be installed along with the modules:\n";
  print join('   ', '', map { s!^.*/!!; $_ } @scripts) . "\n";
  printf("If you don't want these scripts installed, run:\n" .
         "%s Build.PL --no-scripts\n", $build->find_perl_interpreter);
} else {
  print "No scripts will be installed (installing modules only)\n";
}
