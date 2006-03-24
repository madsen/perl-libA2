# Before `./Build install' is performed this script should be runnable with
# `./Build test'. After `./Build install' it should work as `perl 20_ProDOS.t'
#---------------------------------------------------------------------
# $Id$
# Copyright 2006 Christopher J. Madsen
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Test the AppleII::ProDOS module
#---------------------------------------------------------------------

use FindBin;

use strict;
use Test::More tests => 17;
BEGIN { use_ok('AppleII::ProDOS') };

#---------------------------------------------------------------------
# Simple RLE file decompression:
#
# A compressed file just alternates between a count of null bytes and
# a data chunk (count + raw data).  All counts are unsigned network
# shorts.  See compact.pl for the compression code.

sub expand
{
  my ($infile, $outfile) = @_;

  open(IN,  '<', $infile)  or die "Can't open $infile: $!";
  open(OUT, '>', $outfile) or die "Can't open $outfile: $!";
  binmode IN;
  binmode OUT;

  my ($buf, $len, $result) = '';
  while (1) {
    defined($result = read(IN, $buf, 2)) or die $!;
    last unless $result;

    print OUT "\0" x unpack('n', $buf);

    defined($result = read(IN, $buf, 2)) or die $!;
    last unless $result;

    $len = unpack('n', $buf);

    if ($len) {
      read(IN, $buf, $len) or die $!;
      print OUT $buf;
    } # end if data chunk is not empty
  } # end while more data in compressed file

  close IN;
  close OUT or die "Closing $outfile: $!";
} # end expand

#=====================================================================
# Create the test file:

my $dir = "$FindBin::Bin/tmpdir";
mkdir $dir;
chdir $dir or die "Can't cd $dir: $!";

expand('../testdisk.cmp', 'testdisk.PO');

#---------------------------------------------------------------------
# Tests begin here:

my $vol = AppleII::ProDOS->open("testdisk.PO");
isa_ok($vol, 'AppleII::ProDOS', '$vol');

is($vol->name, 'TESTDISK', 'Volume /TESTDISK');

is($vol->disk_size, 280, '280 blocks');

my $bit = $vol->bitmap;
isa_ok($bit, 'AppleII::ProDOS::Bitmap', '$vol->bitmap');

is($bit->free, 260, '260 blocks free');

is($vol->catalog, <<'', 'Catalog /TESTDISK');
Name           Type Blocks  Modified        Created            Size Subtype
SEEDLING        TXT     1  23-Mar-06 11:28 23-Mar-06 11:28        6  $0000
SPARSE.SAPLING  TXT     3  23-Mar-06 19:47 23-Mar-06 11:34    65032  $0000
SUBDIR          DIR     1  24-Mar-06 15:36 23-Mar-06 19:48      512  $0000
Blocks free: 260     Blocks used: 20     Total blocks: 280

my $file = $vol->get_file('SEEDLING');
isa_ok($file, 'AppleII::ProDOS::File', 'SEEDLING $file');

is($file->as_text, "Hello\n", '$file says Hello');

$file = $vol->get_file('SPARSE.SAPLING');
isa_ok($file, 'AppleII::ProDOS::File', 'SPARSE.SAPLING $file');

is($file->as_text, "Hello," . ("\0" x 0xFDFA) . "World!\n\0",
   'SPARSE.SAPLING says Hello, World!');

is($vol->path('SUBDIR'), '/TESTDISK/SUBDIR/', 'cd SUBDIR');

is($vol->catalog, <<'', 'Catalog /TESTDISK/SUBDIR');
Name           Type Blocks  Modified        Created            Size Subtype
SAPLING         TXT     3  23-Mar-06 19:52 23-Mar-06 19:50      531  $0000
SPARSE.TREE     BIN     5  24-Mar-06 15:36 24-Mar-06 15:35   131106  $1000
Blocks free: 260     Blocks used: 20     Total blocks: 280

$file = $vol->get_file('SAPLING');
isa_ok($file, 'AppleII::ProDOS::File', 'SAPLING $file');

is($file->as_text,
   "This is a sapling file.\n" . ("\0" x 488) . "This is block two.\n",
   'SAPLING $file contents');

$file = $vol->get_file('SPARSE.TREE');
isa_ok($file, 'AppleII::ProDOS::File', 'SPARSE.TREE $file');

is($file->as_text,
   "This is a sparse tree file.\n" . ("\0" x 0x1FFE4)
   . "This is the end of the tree file.\n",
   'SPARSE.TREE $file contents');

#---------------------------------------------------------------------
# Local Variables:
# mode: perl
# End:
