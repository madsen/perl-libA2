#---------------------------------------------------------------------
package AppleII::ProDOS;
#
# Copyright 1996 Christopher J. Madsen
#
# Author: Christopher J. Madsen <ac608@yfn.ysu.edu>
# Created: 26 Jul 1996
# Version: $Revision: 0.1 $ ($Date: 1996/07/28 18:01:41 $)
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
use Carp;
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
    ' $Revision: 0.1 $ ' =~ / (\d+)\.(\d{1,3})(\.[0-9.]+)? /
        or die "Invalid version number";
    $VERSION = $VERSION = sprintf("%d.%03d%s",$1,$2,$3);
} # end BEGIN

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
#   disk:  The AppleII::Disk to use

sub new
{
    my ($type, $disk) = @_;
    my $self = {};
    $self->{disk} = $disk;
    my $volDir = $disk->readBlock(2);
    my ($startBlock, $blocks) = unpack('v2',substr($volDir,0x27,4));
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
        pop @blocks, last unless @blocks[-1];
    }

    $self->{blocks} = \@blocks;
} # end AppleII::ProDOS::Bitmap::readDisk

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
} # end AppleII::ProDOS::Bitmap::writeDisk

#=====================================================================
# Package Return Value:

1;

__END__

# Local Variables:
# tmtrack-file-task: "AppleII::ProDOS.pm"
# End:
