#---------------------------------------------------------------------
package AppleII::ProDOS;
#
# Copyright 1996 Christopher J. Madsen
#
# Author: Christopher J. Madsen <ac608@yfn.ysu.edu>
# Created: 26 Jul 1996
# Version: $Revision: 0.4 $ ($Date: 1996/07/29 21:54:41 $)
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Read/write files on ProDOS disk images
#---------------------------------------------------------------------

require 5.000;
use AppleII::Disk 0.005;
use Carp;
use POSIX 'mktime';
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(packName parseName parseDate);

#=====================================================================
# Package Global Variables:

BEGIN
{
    # Convert RCS revision number to d.ddd format:
    ' $Revision: 0.4 $ ' =~ / (\d+)\.(\d{1,3})(\.[0-9.]+)? /
        or die "Invalid version number";
    $VERSION = $VERSION = sprintf("%d.%03d%s",$1,$2,$3);
} # end BEGIN

#=====================================================================
# package AppleII::ProDOS:
#
# Member Variables:
#   bitmap:    An AppleII::ProDOS::Bitmap containing the volume bitmap
#   disk:      An AppleII::Disk
#   diskSize:  The number of blocks on the disk
#   volume:    The volume name of the disk
#---------------------------------------------------------------------
# Constructor:
#
# There are two forms:
#   new(disk); or
#   new(filename, mode);
#
# Input:
#   disk:
#     The AppleII::Disk to use
#   filename:
#     The pathname of the image file you want to open
#   mode:
#     A string indicating how the image should be opened
#     May contain any of the following characters (case sensitive):
#       r  Allow reads (this is actually ignored; you can always read)
#       w  Allow writes

sub new
{
    my ($type, $disk, $mode) = @_;
    my $self = {};
    $disk = AppleII::Disk->new($disk, $mode) unless ref $disk;
    $self->{disk} = $disk;

    my $volDir = $disk->readBlock(2);

    my $storageType;
    ($storageType, $self->{volume}) = parseName(substr($volDir,0x04,16));
    die "This is not a ProDOS disk" unless $storageType == 0xF;

    my ($startBlock, $blocks) = unpack('x39v2',$volDir);

    $self->{bitmap} = AppleII::ProDOS::Bitmap->new($disk,$startBlock,$blocks);
    $self->{diskSize} = $blocks;

    bless $self, $type;
} # end AppleII::ProDOS::new

#---------------------------------------------------------------------
# Convert a filename to ProDOS format (length nibble):
#
# This is NOT a method; it's just a regular subroutine.
#
# Input:
#   type:  The high nibble of the type/length byte
#   name:  The name
#
# Returns:
#   Packed string

sub packName
{
    pack('Ca15',($_[0] << 4) + length($_[1]), uc $_[1]);
} # end AppleII::ProDOS::parseName

#---------------------------------------------------------------------
# Extract a date & time:
#
# This is NOT a method; it's just a regular subroutine.
#
# Input:
#   dateField:  The date/time field
#
# Returns:
#   Standard time for use with gmtime (not localtime)

sub parseDate
{
    my ($date, $minute, $hour) = unpack('vC2', $_[0]);
    my ($year, $month, $day) = ($date>>9, (($date>>5) & 0x0F), $date & 0x1F);
    mktime(0, $minute, $hour, $day, $month-1, $year);
} # end AppleII::ProDOS::parseDate

#---------------------------------------------------------------------
# Extract a filename:
#
# This is NOT a method; it's just a regular subroutine.
#
# Input:
#   nameField:  The type/length byte followed by the name
#
# Returns:
#   (type, name)

sub parseName
{
    my $typeLen = ord $_[0];
    ($typeLen >> 4, substr($_[0],1,$typeLen & 0x0F));
} # end AppleII::ProDOS::parseName

#=====================================================================
package AppleII::ProDOS::Bitmap;
#
# Member Variables:
#   bitmap:    The volume bitmap itself
#   blocks:    An array of the block numbers where the bitmap is stored
#   disk:      An AppleII::Disk
#   diskSize:  The number of blocks on the disk
#---------------------------------------------------------------------

use Carp;
use strict;

# Map ProDOS bit order to Perl's vec():
my @adjust = (7, 5, 3, 1, -1, -3, -5, -7);

#---------------------------------------------------------------------
# Constructor:
#
# Input:
#   disk:        The AppleII::Disk to use
#   startBlock:  The block number where the volume bitmap begins
#   blocks:      The size of the disk in blocks
#     STARTBLOCK & BLOCKS are optional.  If they are omitted, we get
#     the information from the volume directory.

sub new
{
    my ($type, $disk, $startBlock, $blocks) = @_;
    my $self = {};
    $self->{disk} = $disk;
    unless ($startBlock and $blocks) {
        my $volDir = $disk->readBlock(2);
        ($startBlock, $blocks) = unpack('v2',substr($volDir,0x27,4));
    }
    $self->{diskSize} = $blocks;
    do {
        push @{$self->{blocks}}, $startBlock++;
    } while ($blocks -= 0x1000) > 0;
    $self->{bitmap} = $disk->readBlocks($self->{blocks});

    bless $self, $type;
} # end AppleII::ProDOS::Bitmap

#---------------------------------------------------------------------
# See if a block is free:
#
# Input:
#   block:  The block number to check
#
# Returns:
#   True if the block is free

sub isFree
{
    my ($self, $block) = @_;
    croak("No block $block") if $block < 0 or $block >= $self->{diskSize};
    vec($self->{bitmap}, $block + $adjust[$block % 8],1);
} # end AppleII::ProDOS::Bitmap::isFree

#---------------------------------------------------------------------
# Mark blocks as free or used:
#
# Input:
#   blocks:  A block number or list of block numbers to mark
#   mark:    1 for Free, 0 for Used

sub mark
{
    my ($self, $blocks, $mark) = @_;
    my $diskSize = $self->{diskSize};
    $blocks = [ $blocks ] unless ref $blocks;

    my $block;
    foreach $block (@$blocks) {
        croak("No block $block") if $block < 0 or $block >= $diskSize;
        vec($self->{bitmap}, $block + $adjust[$block % 8],1) = $mark;
    }
} # end AppleII::ProDOS::Bitmap::isFree

#---------------------------------------------------------------------
# Read bitmap from disk:

sub readDisk
{
    my $self = shift;
    $self->{bitmap} = $self->{disk}->readBlocks($self->{blocks});
} # end AppleII::ProDOS::Bitmap::readDisk

#---------------------------------------------------------------------
# Write bitmap to disk:

sub writeDisk
{
    my $self = shift;
    $self->{disk}->writeBlocks($self->{blocks}, $self->{bitmap});
} # end AppleII::ProDOS::Bitmap::writeDisk

#=====================================================================
package AppleII::ProDOS::Directory;
#
# Member Variables:
#   access:
#     The access attributes for this directory
#   blocks:
#     The list of blocks used by this directory
#   disk:
#     An AppleII::Disk
#   entries:
#     The list of directory entries
#   name:
#     The directory name
#   created:
#     The date/time the directory was created
#   type:
#     0xF for a volume directory, 0xE for a subdirectory
#   version:
#     The contents of the VERSION & MIN_VERSION (2 byte string)
#
# For the volume directory:
#   bitmap:    The block number where the volume bitmap begins
#   diskSize:  The number of blocks on the disk
#
# For subdirectories:
#   parent:     The AppleII::ProDOS::Directory containing this directory
#   parentNum:  Our entry number within the parent directory
#---------------------------------------------------------------------

AppleII::ProDOS->import(qw(packName parseName));
use strict;

#---------------------------------------------------------------------
# Constructor:
#
# Input:
#   disk:   An AppleII::Disk
#   block:  The block number to use
#   parent:  The parent directory
#   parentNum:  The entry number in the parent directory

sub new
{
    my ($type, $disk, $block, $parent, $parentNum) = @_;
    my $self = {};
    $self->{disk} = $disk;

    if ($parent) {
        $self->{parent}    = $parent;
        $self->{parentNum} = $parentNum;
    }

    bless $self, $type;
    $self->readDisk($block);
    $self;
} # end AppleII::ProDOS::Directory::new

#---------------------------------------------------------------------
# Read directory from disk:

sub readDisk
{
    my ($self, $block) = @_;
    $block = $self->{blocks}[0] unless $block;

    my (@blocks,@entries);
    my $disk = $self->{disk};
    my $entry = 0;
    while ($block) {
        push @blocks, $block;
        my $data = $disk->readBlock($block);
        $block = unpack('v',substr($data,0x02,2)); # Pointer to next block
        substr($data,0,4) = '';                    # Remove block pointers
        while ($data) {
            my ($type, $name) = parseName($data);
            if (($type & 0xE) == 0xE) {
                # Directory header
                $self->{name} = $name;
                $self->{type} = $type;
                $self->{created} = substr($data, 0x1C-4,4);
                $self->{version} = substr($data, 0x20-4,2);
                $self->{access}  = ord substr($data, 0x22-4,1);
                # For volume directory, read bitmap location and disk size:
                @{$self}{'bitmap','diskSize'} =
                    unpack('v2',substr($data,0x27-4,4))
                        if $type == 0xF;
            } elsif ($type) {
                # File entry
                push @entries, AppleII::ProDOS::DirEntry->new($entry, $data);
            }
            substr($data,0,0x27) = ''; # Remove record
            ++$entry;
        } # end while more records
    } # end if rebuilding block list

    $self->{blocks}  = \@blocks;
    $self->{entries} = \@entries;
} # end AppleII::ProDOS::Directory::readDisk

#---------------------------------------------------------------------
# Write directory to disk:

sub writeDisk
{
    my ($self) = @_;

    my $disk    = $self->{disk};
    my @blocks  = @{$self->{blocks}};
    my @entries = @{$self->{entries}};
    my $keyBlock = $blocks[0];
    push    @blocks, 0;         # Add marker at beginning and end
    unshift @blocks, 0;

    my ($i, $entry);
    for ($i=1, $entry=0; $i < $#blocks; $i++) {
        my $data = pack('v2',$blocks[$i-1],$blocks[$i+1]); # Block pointers
        while (length($data) < 0x1FF) {
            if ($entry) {
                # Add a file entry:
                if (@entries and $entries[0]{num} == $entry) {
                    $data .= $entries[0]->packed($keyBlock); shift @entries;
                } else {
                    $data .= "\0" x 0x27;
                }
            } else {
                # Add the directory header:
                $data .= packName(@{$self}{'type','name'});
                $data .= "\0" x 8; # 8 bytes reserved
                $data .= $self->{created};
                $data .= $self->{version};
                $data .= chr $self->{access};
                $data .= "\x27\x0D"; # Entry length, entries per block
                $data .= pack('v',$#entries+1);
                if ($self->{type} == 0xF) {
                    $data .= pack('v2',@{$self}{'bitmap','diskSize'});
                } else {
                    $data .= pack('vCC',@{$self}{'parent','parentNum'},
                                  0x27); # Parent entry length
                } # end else subdirectory
            } # end else if directory header
            ++$entry;
        } # end while more room in block
        $disk->writeBlock($blocks[$i],$data."\0");
    } # end for each directory block
} # end AppleII::ProDOS::Directory::writeDisk

#=====================================================================
package AppleII::ProDOS::DirEntry;
#
# Member Variables:
#   storage:  The storage type
#   name:     The filename
#   type:     The file type
#   block:    The key block for this file
#   blocks:   The number of blocks used by this file
#   size:     The file size in bytes
#   created:  The creation date/time
#   access:   The access attributes
#   auxtype:  The auxiliary type
#   modified: The date/time of last modification
#   num:      The entry number of this entry
#---------------------------------------------------------------------
AppleII::ProDOS->import(qw(packName parseName));
use integer;
use strict;

#---------------------------------------------------------------------
# Constructor:
#
# Input:
#   number:  The entry number
#   entry:   The directory entry

sub new
{
    my ($type, $number, $entry) = @_;
    my $self = {};

    $self->{num} = $number;
    @{$self}{'storage', 'name'} = parseName($entry);
    @{$self}{qw(type block blocks size)} = unpack('x16Cv2V',$entry);
    $self->{size} &= 0xFFFFFF;  # Size is only 3 bytes long
    @{$self}{qw(access auxtype)} = unpack('x30Cv',$entry);

    $self->{created}  = substr($entry,0x18,4);
    $self->{modified} = substr($entry,0x21,4);

    bless $self, $type;
} # end AppleII::ProDOS::DirEntry::new

#---------------------------------------------------------------------
# Return the entry as a packed string:
#
# Input:
#   keyBlock:  The block number of the beginning of the directory
#
# Returns:
#   A directory entry ready to put in a ProDOS directory

sub packed
{
    my ($self, $keyBlock) = @_;
    my $data = packName(@{$self}{'storage', 'name'});
    $data .= pack('Cv2VX',@{$self}{qw(type block blocks size)});
    $data .= $self->{created} . "\0\0";
    $data .= pack('Cv',@{$self}{qw(access auxtype)});
    $data .= $self->{modified};
    $data .= pack('v',$keyBlock);
} # end AppleII::ProDOS::DirEntry::packed

#=====================================================================
package AppleII::ProDOS::Index;
#
# Member Variables:
#   block:   The block number of the index block
#   blocks:  The list of blocks pointed to by this index block
#   disk:    An AppleII::Disk
#---------------------------------------------------------------------

use integer;
use strict;

#---------------------------------------------------------------------
# Constructor:
#
# Input:
#   disk:   An AppleII::Disk
#   block:  The block number to use

sub new
{
    my ($type, $disk, $block) = @_;
    my $self = {};
    $self->{disk} = $disk;
    $self->{block} = $block;

    bless $self, $type;
    $self->readDisk;
    $self;
} # end AppleII::ProDOS::Index::new;

#---------------------------------------------------------------------
# Read contents of index block from disk:

sub readDisk
{
    my $self = shift;
    my @dataLo = unpack('C*',$self->{disk}->readBlock($self->{block}));
    my @dataHi = splice @dataLo, 0x100;
    my @blocks;

    while (@dataLo) {
        push @blocks, shift(@dataLo) + 0x100 * shift(@dataHi);
    }

    $self->{blocks} = \@blocks;
} # end AppleII::ProDOS::Index::readDisk

#---------------------------------------------------------------------
# Write bitmap to disk:

sub writeDisk
{
    my $self = shift;
    my $disk = $self->{disk};

    my ($dataLo, $dataHi);
    $dataLo = $dataHi = pack('v*',@{$self->{blocks}});
    $dataLo =~ s/([\s\S])[\s\S]/$1/g; # Keep just the low byte
    $dataHi =~ s/[\s\S]([\s\S])/$1/g; # Keep just the high byte

    $disk->writeBlock($self->{block},
                      $disk->padBlock($dataLo,"\0",0x100) . $dataHi,
                      "\0");
} # end AppleII::ProDOS::Index::writeDisk

#=====================================================================
# Package Return Value:

1;

__END__

# Local Variables:
# tmtrack-file-task: "AppleII::ProDOS.pm"
# End:
