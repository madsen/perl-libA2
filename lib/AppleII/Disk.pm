#---------------------------------------------------------------------
package AppleII::Disk;
#
# Copyright 1996 Christopher J. Madsen
#
# Author: Christopher J. Madsen <ac608@yfn.ysu.edu>
# Created: 25 Jul 1996
# Version: $Revision: 0.2 $ ($Date: 1996/07/26 16:24:00 $)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Perl; see the file COPYING.  If not, write to the
# Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
#
# Read/Write Apple II disk images
#---------------------------------------------------------------------

require 5.000;
use Carp;
use FileHandle;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw();

#=====================================================================
# Package Global Variables:

BEGIN
{
    # Convert RCS revision number to d.ddd format:
    ' $Revision: 0.2 $ ' =~ / (\d+)\.(\d{1,3})(\.[0-9.]+)? /
        or die "Invalid version number";
    $VERSION = $VERSION = sprintf("%d.%03d%s",$1,$2,$3);
} # end BEGIN

#=====================================================================
# Class AppleII::Disk:
#
# Member Variables:
#   filename:  The pathname of the disk image file
#   writable:  True if the image is opened in read/write mode
#   file:      The FileHandle attached to the image file
#   actlen:    The size of the image file in bytes
#   maxlen:    The maximum allowable size of the image file in bytes
#---------------------------------------------------------------------
# Constructor:
#
# Input:
#   filename:
#     The pathname of the image file you want to open
#   mode:
#     A string indicating how the image should be opened
#     May contain any of the following characters (case sensitive):
#       r  Allow reads (this is actually ignored; you can always read)
#       w  Allow writes

sub new
{
    my ($type, $filename, $mode) = @_;
    my $self = {};
    $self->{filename} = $filename;

    my $file = new FileHandle;

    $mode = 'r' unless $mode;
    my $openMode = '<';
    if ($mode =~ /w/) {
        $self->{writable} = 1;
        $openMode = '+<';
        $file->open(">$filename") or croak("Couldn't create `$filename'")
            if not -e $filename; # Create empty file
    } # end if writable

    $file->open("$openMode$filename") or croak("Couldn't open `$filename'");
    binmode $file;

    $self->{file}   = $file;
    $self->{actlen} = (stat $file)[7]; # Get real size of file
    $self->{maxlen} = $self->{actlen};
    bless $self, $type;
} # end AppleII::Disk::new

#---------------------------------------------------------------------
# Read a ProDOS block:
#
# Input:
#   block:  The block number to read
#
# Returns:
#   A 512 byte block
#
# Implemented in AppleII::Disk::ProDOS & AppleII::Disk::DOS33

#---------------------------------------------------------------------
# Read a DOS 3.3 sector:
#
# Input:
#   track:   The track number to read
#   sector:  The sector number to read
#
# Returns:
#   A 256 byte sector
#
# Implemented in AppleII::Disk::ProDOS & AppleII::Disk::DOS33

#---------------------------------------------------------------------
# Write a ProDOS block:
#
# Input:
#   block:  The block number to read
#   data:   The contents of the block
#   pad:    A character to pad the block with (optional)
#     If pad is omitted, an error is generated if data is not 512 bytes
#
# Implemented in AppleII::Disk::ProDOS & AppleII::Disk::DOS33

#---------------------------------------------------------------------
# Write a DOS 3.3 sector:
#
# Input:
#   track:   The track number to read
#   sector:  The sector number to read
#   data:   The contents of the sector
#   pad:    The value to pad the sector with (optional)
#     If pad is omitted, an error is generated if data is not 256 bytes
#
# Implemented in AppleII::Disk::ProDOS & AppleII::Disk::DOS33

#=====================================================================
package AppleII::Disk::ProDOS;
#
# Handle ProDOS-order disk images
#---------------------------------------------------------------------

use Carp;
use FileHandle;
use integer;

@ISA = qw(AppleII::Disk);

#---------------------------------------------------------------------
# Read a block from a ProDOS order disk:
#
# See AppleII::Disk::readBlock

sub readBlock
{
    my $self = shift;

    return "\0" x 0x200
        if $self->seekBlock($_[0]) >= $self->{actlen}; # Past EOF
    my $buffer = '';
    read($self->{file},$buffer,0x200) or die;

    $buffer;
} # end AppleII::Disk::ProDOS::readBlock

#---------------------------------------------------------------------
# FIXME AppleII::Disk::ProDOS::readSector not implemented yet

#---------------------------------------------------------------------
# Seek to the beginning of a block:
#
# Input:
#   block:  The block number to seek to
#
# Returns:
#   The new position of the file pointer

sub seekBlock
{
    my ($self, $block) = @_;

    my $pos = $block * 0x200;
    croak("Invalid block number $block")
        if $pos < 0 or $pos >= $self->{maxlen};

    $self->{file}->seek($pos,0) or die;

    $pos;
} # end AppleII::Disk::ProDOS::seekBlock

#---------------------------------------------------------------------
# Write a block from a ProDOS order disk:
#
# See AppleII::Disk::writeBlock

sub writeBlock
{
    my ($self, $block, $data, $pad) = @_;
    croak("Disk image is read/only") unless $self->{writable};

    $data .= $pad x (0x200 - length($data))
        if (defined $pad and length($data) < 0x200);

    croak(sprintf("Data block is %d bytes",length($data)))
        unless length($data) == 0x200;

    $self->seekBlock($block);
    print {$self->{file}} $data or die;
    $self->{actlen} = (stat $self->{file})[7];
} # end AppleII::Disk::ProDOS::writeBlock

#=====================================================================
package AppleII::Disk::DOS33;
#
# Handle DOS 3.3-order disk images
#---------------------------------------------------------------------

#$debug = 1;

use Carp;
use FileHandle;
use integer;

@ISA = qw(AppleII::Disk);

#---------------------------------------------------------------------
# Convert ProDOS block number to track & sectors:

{   my @sector1 = ( 0, 13, 11, 9, 7, 5, 3,  1);
    my @sector2 = (14, 12, 10, 8, 6, 4, 2, 15);

sub block2sector
{
    my $block = shift;
    my $offset = $block % 8;

    ($block/8, $sector1[$offset], $sector2[$offset]); # INTEGER division
} # end block2sector
}

#---------------------------------------------------------------------
# Read a block from a DOS 3.3 order disk:
#
# See AppleII::Disk::readBlock

sub readBlock
{
    my ($self, $block) = @_;
    my ($track, $sector1, $sector2) = block2sector($block);

    $self->readSector($track, $sector1) . $self->readSector($track, $sector2);
} # end AppleII::Disk::DOS33::readBlock

#---------------------------------------------------------------------
# Read a DOS 3.3 sector:
#
# See AppleII::Disk::readSector

sub readSector
{
    my $self = shift;
    return "\0" x 0x100
        if $self->seekSector(@_[0..1]) >= $self->{actlen}; # Past EOF
    my $buffer = '';
    read($self->{file},$buffer,0x100) or die;

    $buffer;
} # end AppleII::Disk::DOS33::readSector

#---------------------------------------------------------------------
# Seek to the beginning of a sector:
#
# Input:
#   track:   The track number to seek to
#   sector:  The sector number to seek to
#
# Returns:
#   The new position of the file pointer

sub seekSector
{
    my ($self, $track, $sector) = @_;

    my $pos = $track * 0x1000 + $sector * 0x100;
    croak("Invalid position track $track sector $sector")
        if $pos < 0 or $pos >= $self->{maxlen};

    $self->{file}->seek($pos,0) or die;
    $pos;
} # end AppleII::Disk::DOS33::seekSector

#---------------------------------------------------------------------
# Write a sector to a DOS 3.3 order image:
#
# See AppleII::Disk::writeSector

sub writeSector
{
    my ($self, $track, $sector, $data, $pad) = @_;
    croak("Disk image is read/only") unless $self->{writable};

    $data .= $pad x (0x100 - length($data))
        if (defined $pad and length($data) < 0x100);

    croak(sprintf("Data block is %d bytes",length($data)))
        unless length($data) == 0x100;

    $self->seekSector($track, $sector);
    print {$self->{file}} $data or die;
    $self->{actlen} = (stat $self->{file})[7];
} # end AppleII::Disk::DOS33::writeSector

#---------------------------------------------------------------------
# Write a block to a DOS33 order disk:
#
# See AppleII::Disk::writeBlock

sub writeBlock
{
    my ($self, $block, $data, $pad) = @_;
    croak("Disk image is read/only") unless $self->{writable};
    my ($track, $sector1, $sector2) = block2sector($block);

    $data .= $pad x (0x200 - length($data))
        if (defined $pad and length($data) < 0x200);

    croak(sprintf("Data block is %d bytes",length($data)))
        unless length($data) == 0x200;

    $self->writeSector($track, $sector1, substr($data,0,0x100));
    $self->writeSector($track, $sector2, substr($data,0x100,0x100));
} # end AppleII::Disk::DOS33::writeBlock

#=====================================================================
# Package Return Value:

1;
