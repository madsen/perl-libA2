#! /usr/bin/perl
#---------------------------------------------------------------------
# Build.PL for LibA2
# Copyright 2011 Christopher J. Madsen
#---------------------------------------------------------------------

use inc::A2_Build;          # Our customized version of Module::Build

my $build = inc::A2_Build->new(
  dist_name          => 'LibA2',
  dist_version       => ##{ "'$version'" ##},
  dist_author        => 'Christopher J. Madsen <perl@cjmweb.net>',
  module_name        => 'AppleII::ProDOS', # for packlist
##{ $plugin->get_prereqs ##}
  get_options        => { 'no-scripts' => undef },
  add_to_cleanup     => [ 't/tmpdir' ],
);

my @scripts;

if ($build->args('no-scripts')) {
  $build->dispatch('clean');   # The scripts might already be in blib/
} else {
  @scripts = qw(##{ join ' ', sort map { $_->name }
                    @{ $zilla->find_files(':ExecFiles') } ##});
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
