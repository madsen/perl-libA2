#! /usr/bin/perl
#---------------------------------------------------------------------
# $Id$
#---------------------------------------------------------------------

use Test::More;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage"
    if $@;

plan tests => 2;

#---------------------------------------------------------------------
pod_coverage_ok('AppleII::Disk', {
  trustme => [ qr/^pad_block$/ ], # Older versions of Pod::Coverage miss this
});

#---------------------------------------------------------------------
my @private = map { qr/^\Q$_\E$/ } qw(
  a2_croak
);

TODO: {
  local $TODO = "documentation unfinished";

  pod_coverage_ok('AppleII::ProDOS', {
    also_private => \@private,
  });
}
