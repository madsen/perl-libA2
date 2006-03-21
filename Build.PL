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
  dist_version       => '0.04',
  dist_author        => 'Christopher J. Madsen <cjm@pobox.com>',
  dist_abstract      => 'Apple II emulator & file utilities',
  license            => 'perl',
  requires           => { perl => '5.6.0' },
  script_files       => [ glob "$FindBin::Bin/bin/*.pl" ],
  create_makefile_pl => 'passthrough',
);
$build->create_build_script;

# Local Variables:
#   tmtrack-file-task: "LibA2: Build.PL"
# End:
