#!perl
#---------------------------------------------------------------------
# $Id: pro_fmt.pl,v 0.1 1996/08/01 21:04:56 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# Create a blank ProDOS disk image
#---------------------------------------------------------------------

use AppleII::Disk   0.005;
use String::Hex     0.002;

my $disk = AppleII::Disk->new($ARGV[0],'w');
$disk->{maxlen} = 280 * 0x200;

my $block = hexString <<'';
00 00  # No previous block
03 00  # Next block is block 3
F7 4e 45 57 44 49 53 4b 00 x 8 # Volume name NEWDISK
00 x 8 # 8 bytes reserved
00 x 4 # Creation date/time
00 00  # Version numbers
E3     # Access permission
27 0D  # Entry length, entries per block
00 00  # File count
06 00  # Volume bit map
18 01  # 280 blocks

$disk->writeBlock(2,$block,"\0");
$disk->writeBlock(3,hexString('0200 0400'),"\0"); # Block 3, directory
$disk->writeBlock(4,hexString('0300 0500'),"\0"); # Block 4, directory
$disk->writeBlock(5,hexString('0400 0000'),"\0"); # Block 5, directory
$disk->writeBlock(6,hexString('01 F x 44'),"\0"); # Block 6, volume bit map
