#---------------------------------------------------------------------
package AppleII::Disk;
#
# Copyright 1996 Christopher J. Madsen
#
# Author: Christopher J. Madsen <cjm@pobox.com>
# Created: 25 Jul 1996
# Version: $Revision: 0.10 $ ($Date: 2005/01/15 05:37:23 $)
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Read/Write Apple II disk images
#---------------------------------------------------------------------

require 5.000;
use Carp;
use FileHandle;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw();

#=====================================================================
# Package Global Variables:

BEGIN
{
    # Convert RCS revision number to d.ddd format:
    ' $Revision: 0.10 $ ' =~ / (\d+)\.(\d{1,3})(\.[0-9.]+)? /
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
#       d  Disk image is in DOS 3.3 order (default)
#       p  Disk image is in ProDOS order

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

    $type = 'AppleII::Disk::ProDOS' if $mode =~ /p/;
    $type = 'AppleII::Disk::DOS33'  if $mode =~ /d/;
    $type = (($filename =~ /\.(?:hdv|po)$/i)
             ? 'AppleII::Disk::ProDOS'
             : 'AppleII::Disk::DOS33')
        if ($type eq 'AppleII::Disk');
    bless $self, $type;
} # end AppleII::Disk::new

#---------------------------------------------------------------------
# Pad a block of data:
#
# Input:
#   data:    The block to be padded
#   pad:     The character to pad with (default "\0") or '' for no padding
#   length:  The length to pad to (default 0x200)
#
# Returns:
#   The BLOCK padded to LENGTH with PAD
#     Dies if the block is too long.
#     If PAD is the null string, dies if BLOCK is not already LENGTH.

sub pad_block
{
    my ($self, $data, $pad, $length) = @_;

    $pad    = "\0" unless defined $pad;
    $length = $length || 0x200;

    $data .= $pad x ($length - length($data))
        if (defined $pad and length($data) < $length);

    unless (length($data) == $length) {
        local $Carp::CarpLevel = $Carp::CarpLevel;
        ++$Carp::CarpLevel if (caller)[0] =~ /^AppleII::Disk::/;
        croak(sprintf("Data block is %d bytes",length($data)));
    }

    $data;
} # end AppleII::Disk::pad_block

#---------------------------------------------------------------------
# Get or set the disk size:
#
# Input:
#   size:  The number of blocks in the disk image
#          If SIZE is omitted, the disk size is not changed
#
# Returns:
#   The number of blocks in the disk image

sub blocks
{
    my $self = shift;

    if (@_) {
        $self->{maxlen} = $_[0] * 0x200;
        carp "Disk image contains more than $_[0] blocks"
            if $self->{maxlen} < $self->{actlen};
    }

    int($self->{maxlen} / 0x200);
} # end AppleII::Disk::blocks

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
#
# sub read_block

#---------------------------------------------------------------------
# Read a series of ProDOS blocks:
#
# Input:
#   blocks:  An array of block numbers to read
#
# Returns:
#   The data from the disk (512 bytes times the number of blocks)

sub read_blocks
{
    my ($self, $blocks) = @_;
    my $data = '';
    foreach (@$blocks) {
        $data .= $self->read_block($_);
    }
    $data;
} # end AppleII::Disk::read_blocks

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
#
# sub read_sector

#---------------------------------------------------------------------
# Write a ProDOS block:
#
# Input:
#   block:  The block number to read
#   data:   The contents of the block
#   pad:    A character to pad the block with (optional)
#     If PAD is omitted, an error is generated if data is not 512 bytes
#
# Implemented in AppleII::Disk::ProDOS & AppleII::Disk::DOS33
#
# sub write_block

#---------------------------------------------------------------------
# Write a series of ProDOS blocks:
#
# Input:
#   blocks:  An array of the block numbers to write to
#   data:    The data to write (must be exactly the right size)
#   pad:     A character to pad the last block with (optional)

sub write_blocks
{
    my ($self, $blocks, $data, $pad) = @_;
    my $index = 0;
    foreach (@$blocks) {
        $self->write_block($_, substr($data, $index, 0x200), $pad);
        $index += 0x200;
    }
} # end AppleII::Disk::write_blocks

#---------------------------------------------------------------------
# Write a DOS 3.3 sector:
#
# Input:
#   track:   The track number to read
#   sector:  The sector number to read
#   data:   The contents of the sector
#   pad:    The value to pad the sector with (optional)
#     If PAD is omitted, an error is generated if data is not 256 bytes
#
# Implemented in AppleII::Disk::ProDOS & AppleII::Disk::DOS33
#
# sub write_sector

#=====================================================================
package AppleII::Disk::ProDOS;
#
# Handle ProDOS-order disk images
#---------------------------------------------------------------------

use Carp;
use FileHandle;
use integer;
use strict;
use vars qw(@ISA);

@ISA = qw(AppleII::Disk);

#---------------------------------------------------------------------
# Read a block from a ProDOS order disk:
#
# See AppleII::Disk::read_block

sub read_block
{
    my $self = shift;

    return "\0" x 0x200
        if $self->seek_block($_[0]) >= $self->{actlen}; # Past EOF
    my $buffer = '';
    read($self->{file},$buffer,0x200) or die;

    $buffer;
} # end AppleII::Disk::ProDOS::read_block

#---------------------------------------------------------------------
# FIXME AppleII::Disk::ProDOS::read_sector not implemented yet

#---------------------------------------------------------------------
# Seek to the beginning of a block:
#
# Input:
#   block:  The block number to seek to
#
# Returns:
#   The new position of the file pointer

sub seek_block
{
    my ($self, $block) = @_;

    my $pos = $block * 0x200;
    croak("Invalid block number $block")
        if $pos < 0 or $pos >= $self->{maxlen};

    $self->{file}->seek($pos,0) or die;

    $pos;
} # end AppleII::Disk::ProDOS::seek_block

#---------------------------------------------------------------------
# Write a block from a ProDOS order disk:
#
# See AppleII::Disk::write_block

sub write_block
{
    my ($self, $block, $data, $pad) = @_;
    croak("Disk image is read/only") unless $self->{writable};

    $data = $self->pad_block($data, $pad || '');

    $self->seek_block($block);
    print {$self->{file}} $data or die;
    $self->{actlen} = (stat $self->{file})[7];
} # end AppleII::Disk::ProDOS::write_block

#=====================================================================
package AppleII::Disk::DOS33;
#
# Handle DOS 3.3-order disk images
#---------------------------------------------------------------------

#$debug = 1;

use Carp;
use FileHandle;
use integer;
use strict;
use vars qw(@ISA);

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
# See AppleII::Disk::read_block

sub read_block
{
    my ($self, $block) = @_;
    my ($track, $sector1, $sector2) = block2sector($block);

    $self->read_sector($track,$sector1) . $self->read_sector($track,$sector2);
} # end AppleII::Disk::DOS33::read_block

#---------------------------------------------------------------------
# Read a DOS 3.3 sector:
#
# See AppleII::Disk::read_sector

sub read_sector
{
    my $self = shift;
    return "\0" x 0x100
        if $self->seek_sector(@_[0..1]) >= $self->{actlen}; # Past EOF
    my $buffer = '';
    read($self->{file},$buffer,0x100) or die;

    $buffer;
} # end AppleII::Disk::DOS33::read_sector

#---------------------------------------------------------------------
# Seek to the beginning of a sector:
#
# Input:
#   track:   The track number to seek to
#   sector:  The sector number to seek to
#
# Returns:
#   The new position of the file pointer

sub seek_sector
{
    my ($self, $track, $sector) = @_;

    my $pos = $track * 0x1000 + $sector * 0x100;
    croak("Invalid position track $track sector $sector")
        if $pos < 0 or $pos >= $self->{maxlen};

    $self->{file}->seek($pos,0) or die;
    $pos;
} # end AppleII::Disk::DOS33::seek_sector

#---------------------------------------------------------------------
# Write a sector to a DOS 3.3 order image:
#
# See AppleII::Disk::write_sector

sub write_sector
{
    my ($self, $track, $sector, $data, $pad) = @_;
    croak("Disk image is read/only") unless $self->{writable};

    $data = $self->pad_block($data, $pad || '', 0x100);

    $self->seek_sector($track, $sector);
    print {$self->{file}} $data or die;
    $self->{actlen} = (stat $self->{file})[7];
} # end AppleII::Disk::DOS33::write_sector

#---------------------------------------------------------------------
# Write a block to a DOS33 order disk:
#
# See AppleII::Disk::write_block

sub write_block
{
    my ($self, $block, $data, $pad) = @_;
    croak("Disk image is read/only") unless $self->{writable};
    my ($track, $sector1, $sector2) = block2sector($block);

    $data = $self->pad_block($data, $pad || '');

    $self->write_sector($track, $sector1, substr($data,0,0x100));
    $self->write_sector($track, $sector2, substr($data,0x100,0x100));
} # end AppleII::Disk::DOS33::write_block

#=====================================================================
# Package Return Value:

1;

__END__

=head1 NAME

AppleII::Disk - Block-level access to Apple II disk image files

=head1 SYNOPSIS

    use AppleII::Disk;
    my $disk = AppleII::Disk->new('image.dsk');
    my $data = $disk->read_block(1);  # Read block 1
    $disk->write_block(1, $data);     # And write it back :-)

=head1 DESCRIPTION

C<AppleII::Disk> provides block-level access to the Apple II disk
image files used by most Apple II emulators.  (For information about
Apple II emulators, try the Apple II Emulator Page at
L<http://www.ecnet.net/users/mumbv/pages/apple2.shtml>.)  For a
higher-level interface, use the L<AppleII::ProDOS> module.

C<AppleII::Disk> provides the following methods:

=over 4

=item $disk = AppleII::Disk->new($filename, [$mode])

Constructs a new C<AppleII::Disk> object.  C<$filename> is the name of
the image file.  The optional C<$mode> is a string specifying how to
open the image.  It can consist of the following characters (I<case
sensitive>):

    r  Allow reads (this is actually ignored; you can always read)
    w  Allow writes
    d  Disk image is in DOS 3.3 order
    p  Disk image is in ProDOS order

If you don't specify 'd' or 'p', then the format is guessed from the
filename.  '.PO' and '.HDV' files are ProDOS order, and anything else
is assumed to be DOS 3.3 order.

If you specify 'w' to allow writes, then the image file is created if
it doesn't already exist.

=item $size = $disk->blocks([$newsize])

Gets or sets the size of the disk in blocks.  C<$newsize> is the new
size of the disk in blocks.  If C<$newsize> is omitted, then the size
is not changed.  Returns the size of the disk image in blocks.

This refers to the I<logical> size of the disk image.  Blocks outside
the physical size of the disk image read as all zeros.  Writing to
such a block will expand the image file.

When you create a new image file, you must use C<blocks> to set its
size before writing to it.

=item $contents = $disk->read_block($block)

Reads one block from the disk image.  C<$block> is the block number to
read.

=item $contents = $disk->read_blocks(\@blocks)

Reads a sequence of blocks from the disk image.  C<\@blocks> is a
reference to an array of block numbers.

=item $contents = $disk->read_sector($track, $sector)

Reads one sector from the disk image.  C<$track> is the track number,
and C<$sector> is the DOS 3.3 logical sector number.  This is
currently implemented only for DOS 3.3 order images.

=item $disk->write_block($block, $contents, [$pad])

Writes one block to the disk image.  C<$block> is the block number to
write.  C<$contents> is the data to write.  The optional C<$pad> is a
character to pad the block with (out to 512 bytes).  If C<$pad> is
omitted or null, then C<$contents> must be exactly 512 bytes.

=item $disk->write_blocks(\@blocks, $contents, [$pad])

Writes a sequence of blocks to the disk image.  C<\@blocks> is a
reference to an array of block numbers to write.  C<$contents> is the
data to write.  It is broken up into 512 byte chunks and written to
the blocks.  The optional C<$pad> is a character to pad the data with
(out to a multiple of 512 bytes).  If C<$pad> is omitted or null, then
C<$contents> must be exactly 512 bytes times the number of blocks.

=item $disk->write_sector($track, $sector, $contents, [$pad])

Writes one sector to the disk image.  C<$track> is the track number,
and C<$sector> is the DOS 3.3 logical sector number.  C<$contents> is
the data to write.  The optional C<$pad> is a character to pad the
sector with (out to 256 bytes).  If C<$pad> is omitted or null, then
C<$contents> must be exactly 256 bytes.  This is currently implemented
only for DOS 3.3 order images.

=item $padded = AppleII::Disk->pad_block($data, [$pad, [$length]])

Pads C<$data> out to C<$length> bytes with C<$pad>.  Returns the
padded string; the original is not altered.  Dies if C<$data> is
longer than C<$length>.  The default C<$pad> is "\0", and the default
C<$length> is 512 bytes.

If C<$pad> is the null string (not undef), just checks to make sure
that C<$data> is exactly C<$length> bytes and returns the original
string.  Dies if C<$data> is not exactly C<$length> bytes.

C<pad_block> can be called either as C<AppleII::Disk-E<gt>pad_block>
or C<$disk-E<gt>pad_block>.

=back

=head1 AUTHOR

Christopher J. Madsen E<lt>F<cjm@pobox.com>E<gt>

=cut

# Local Variables:
# tmtrack-file-task: "AppleII::Disk.pm"
# End:
