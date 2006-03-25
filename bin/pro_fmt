#! /usr/bin/perl
#---------------------------------------------------------------------
# $Id$
# Copyright 1996-2006 Christopher J. Madsen
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Create a blank ProDOS disk image
#---------------------------------------------------------------------

use AppleII::ProDOS 0.04;
use Getopt::Long 2.10;
use strict;

our $VERSION = '0.04';

#---------------------------------------------------------------------
my $blocks = 280;
my $volume = 'NEWDISK';
my $order  = '';
my ($extendToFullSize, $force);

Getopt::Long::config(qw(bundling no_getopt_compat));
GetOptions(
    'blocks|b=i'      => \$blocks,
    'dos-order|d'     => sub { $order = 'd' },
    'extend|e'        => \$extendToFullSize,
    'force|f'         => \$force,
    'prodos-order|p'  => sub { $order = 'p' },
    'volume|v=s'      => \$volume,
    'help'            => \&usage,
    'version'         => \&usage
) or usage();

my $filename = shift @ARGV;
defined($filename) or usage();

sub usage {
    print "pro_fmt $VERSION\n";
    exit if $_[0] and $_[0] eq 'version';
    print "\n" . <<'';
Usage:  pro_fmt [options] FILE
  -b, --blocks=SIZE  Make the image SIZE blocks (default 280)
  -d, --dos-order    Make a DOS 3.3-order image file
  -e, --extend       Extend FILE to its maximum size
  -f, --force        Overwrite an existing file
  -p, --prodos-order Make a ProDOS-order image file
  -v, --volume=NAME  Use NAME for the ProDOS volume name (default NEWDISK)
      --help         Display this help message
      --version      Display version information

    exit;
} # end usage

#=====================================================================
if (not $force and -e $filename) {
  print STDERR "pro_fmt: $filename already exists (use --force to overwrite)\n";
  exit 1;
}

my $vol = AppleII::ProDOS->new($volume, $blocks, $filename, $order);

$vol->disk->fully_allocate if $extendToFullSize;
