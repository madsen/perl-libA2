#---------------------------------------------------------------------
package AppleII::ProDOS;
#
# Copyright 1996 Christopher J. Madsen
#
# Author: Christopher J. Madsen <ac608@yfn.ysu.edu>
# Created: 26 Jul 1996
# Version: $Revision: 0.9 $ ($Date: 1996/07/31 19:32:39 $)
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
@EXPORT_OK = qw(
    packDate packName parseDate parseName parseType shortDate validName
);

#=====================================================================
# Package Global Variables:

BEGIN
{
    # Convert RCS revision number to d.ddd format:
    ' $Revision: 0.9 $ ' =~ / (\d+)\.(\d{1,3})(\.[0-9.]+)? /
        or die "Invalid version number";
    $VERSION = $VERSION = sprintf("%d.%03d%s",$1,$2,$3);
} # end BEGIN

# Filetype list from About Apple II File Type Notes -- June 1992
my @filetypes = qw(
    NON BAD PCD PTX TXT PDA BIN FNT FOT BA3 DA3 WPF SOS $0D $0E DIR
    RPD RPI AFD AFM AFR SCL PFS $17 $18 ADB AWP ASP $1C $1D $1E $1F
    TDM $21 $22 $23 $24 $25 $26 $27 $28 $29 8SC 8OB 8IC 8LD P8C $2F
    $30 $31 $32 $33 $34 $35 $36 $37 $38 $39 $3A $3B $3C $3D $3E $3F
    DIC $41 FTD $43 $44 $45 $46 $47 $48 $49 $4A $4B $4C $4D $4E $4F
    GWP GSS GDB DRW GDP HMD EDU STN HLP COM CFG ANM MUM ENT DVU FIN
    $60 $61 $62 $63 $64 $65 $66 $67 $68 $69 $6A BIO $6C TDR PRE HDV
    $70 $71 $72 $73 $74 $75 $76 $77 $78 $79 $7A $7B $7C $7D $7E $7F
    $80 $81 $82 $83 $84 $85 $86 $87 $88 $89 $8A $8B $8C $8D $8E $8F
    $90 $91 $92 $93 $94 $95 $96 $97 $98 $99 $9A $9B $9C $9D $9E $9F
    WP  $A1 $A2 $A3 $A4 $A5 $A6 $A7 $A8 $A9 $AA GSB TDF BDF $AE $AF
    SRC OBJ LIB S16 RTL EXE PIF TIF NDA CDA TOL DVR LDF FST $BE DOC
    PNT PIC ANI PAL $C4 OOG SCR CDV FON FND ICN $CB $CC $CD $CE $CF
    $D0 $D1 $D2 $D3 $D4 MUS INS MDI SND $D9 $DA DBM $DC $DD $DE $DF
    LBR $E1 ATK $E3 $E4 $E5 $E6 $E7 $E8 $E9 $EA $EB $EC $ED R16 PAS
    CMD $F1 $F2 $F3 $F4 $F5 $F6 $F7 $F8 OS  INT IVR BAS VAR REL SYS
); # end filetypes

#=====================================================================
# package AppleII::ProDOS:
#
# Member Variables:
#   bitmap:
#     An AppleII::ProDOS::Bitmap containing the volume bitmap
#   directories:
#     Array of AppleII::ProDOS::Directory starting with the volume dir
#   disk:
#     The AppleII::Disk we are accessing
#   diskSize:
#     The number of blocks on the disk
#   volume:
#     The volume name of the disk
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
    croak('This is not a ProDOS disk') unless $storageType == 0xF;

    my ($startBlock, $blocks) = unpack('x39v2',$volDir);

    $self->{bitmap} = AppleII::ProDOS::Bitmap->new($disk,$startBlock,$blocks);
    $self->{directories} = [ AppleII::ProDOS::Directory->new($disk,2) ];
    $self->{diskSize} = $blocks;

    bless $self, $type;
} # end AppleII::ProDOS::new

#---------------------------------------------------------------------
sub catalog
{
    shift->{directories}[-1]->catalog(@_);
} # end AppleII::ProDOS::catalog

#---------------------------------------------------------------------
# Return or change the current directory:

sub directory
{
    my ($self, $newdir) = @_;

    if ($newdir) {
        # Change directory:
        my @directories = @{$self->{directories}};
        pop @directories while $#directories and $newdir =~ s'^\.\.(?:/|$)'';#'
        my $dir;
        foreach $dir (split(/\//, $newdir)) {
            eval { push @directories, $directories[-1]->open($dir) };
            croak("No such directory `$_[1]'") if $@ =~ /^No such directory/;
            die $@ if $@;
        }
        $self->{directories} = \@directories;
    } # end if changing directory

    '/'.join('/',map { $_->{name} } @{$self->{directories}}).'/';
} # end AppleII::ProDOS::directory

#---------------------------------------------------------------------
# Convert a time to ProDOS format:
#
# This is NOT a method; it's just a regular subroutine.
#
# Input:
#   time:  The time to convert
#
# Returns:
#   Packed string

sub packDate
{
    my ($minute,$hour,$day,$month,$year) = (localtime($_[0]))[1..5];
    pack('vC2', ($year<<9) + (($month+1)<<5) + $day, $minute, $hour);
} # end AppleII::ProDOS::packDate

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
} # end AppleII::ProDOS::packName

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
#   undef if no date

sub parseDate
{
    my ($date, $minute, $hour) = unpack('vC2', $_[0]);
    return undef unless $date;
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

#---------------------------------------------------------------------
# Convert a filetype to its abbreviation:
#
# This is NOT a method; it's just a regular subroutine.
#
# Input:
#   type:  The filetype to convert (0-255)
#
# Returns:
#   The abbreviation for the filetype

sub parseType
{
    $filetypes[$_[0]];
} # end AppleII::ProDOS::parseType

#---------------------------------------------------------------------
# Convert a date & time to a short string:
#
# This is NOT a method; it's just a regular subroutine.
#
# Input:
#   dateField:  The date/time field
#
# Returns:
#   "dd-Mmm-yy hh:mm" or "<No Date>      "

my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

sub shortDate
{
    my ($date, $minute, $hour) = unpack('vC2', $_[0]);
    return "<No Date>      " unless $date;
    my ($year, $month, $day) = ($date>>9, (($date>>5) & 0x0F), $date & 0x1F);
    sprintf('%2d-%s-%02d %2d:%02d',$day,$months[$month-1],$year,$hour,$minute);
} # end AppleII::ProDOS::shortDate

#---------------------------------------------------------------------
# Determine if a filename is valid:
#
# May be called as a method or a normal subroutine.
#
# Input:
#   The file to check
#
# Returns:
#   True if the filename is valid

sub validName
{
    $_[-1] =~ /\A[a-z][a-z0-9.]{0,14}\Z(?!\n)/i;
} # end AppleII::ProDOS::validName

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
} # end AppleII::ProDOS::Bitmap::new

#---------------------------------------------------------------------
# Get some free blocks:
#
# Input:
#   count:  The number of blocks requested
#
# Returns:
#   A list of block numbers (which have been marked as used)
#   The empty list if there aren't enough free blocks

sub getBlocks
{
    my ($self, $count) = @_;
    my (@blocks,$i);
    my $diskSize = $self->{diskSize};
    for ($i=3; $i < $diskSize; $i++) {
        if ($self->isFree($i)) {
            push @blocks, $i;
            last unless --$count;
        }
    }
    return () if $count;        # We couldn't find enough
    $self->mark(\@blocks,0);    # Mark blocks as in use
    @blocks;
} # end AppleII::ProDOS::Bitmap::getBlocks

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
#   parent:     The block number where the parent directory begins
#   parentNum:  Our entry number within the parent directory
#---------------------------------------------------------------------

AppleII::ProDOS->import(qw(packName parseName shortDate));
use Carp;
use strict;

#---------------------------------------------------------------------
# Constructor:
#
# Input:
#   disk:       An AppleII::Disk
#   block:      The block number where the directory begins
#   parent:     The block number where the parent directory begins
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
# Add entry:
#
# Dies if the entry can't be added.
#
# Input:
#   entry:  An AppleII::ProDOS::DirEntry

sub addEntry
{
    my ($self,$entry) = @_;
    my $entries = $self->{entries};

    my $lastEntry = 0xD * (1 + $#{$self->{blocks}});

    my $i;
    for ($i=0; $i <= $#$entries; ++$i) {
        last if $entries->[$i]{num} > $i+1;
    }

    croak('Directory full') if ($i > $lastEntry); # FIXME expand dir

    $entry->{num} = $i+1;
    splice @$entries, $i, 0, $entry;
} # end AppleII::ProDOS::Directory::addEntry

#---------------------------------------------------------------------
# Return the catalog:
#
# Returns:
#   A string containing the catalog in ProDOS format

sub catalog
{
    my $self = shift;
    my $result =
        sprintf("%-15s%s %s  %-14s  %-14s %8s %s\n",
                qw(Name Type Blocks Modified Created Size Subtype));
    my $entry;
    foreach $entry (@{$self->{entries}}) {
        $result .= sprintf("%-15s %-3s %5d  %s %s %8d  \$%04X\n",
                           $entry->name, $entry->shortType, $entry->blocks,
                           shortDate($entry->modified),
                           shortDate($entry->created),
                           $entry->size, $entry->auxtype);
    }
    $result;
} # end AppleII::ProDOS::Directory::catalog

#---------------------------------------------------------------------
# Find an entry:
#
# Input:
#   filename:  The filename to match
#
# Returns:
#   The entry representing that filename

sub findEntry
{
    my ($self, $filename) = @_;
    $filename = uc $filename;
    (grep {uc($_->name) eq $filename} @{$self->{entries}})[0];
} # end AppleII::ProDOS::Directory::findEntry

#---------------------------------------------------------------------
# Open a subdirectory:
#
# Input:
#   dir:  The name of the subdirectory to open
#
# Returns:
#   A new AppleII::ProDOS::Directory object for the subdirectory

sub open
{
    my ($self, $dir) = @_;

    my $entry = $self->findEntry($dir)
        or croak("No such directory `$dir'");

    AppleII::ProDOS::Directory->new($self->{disk}, $entry->block,
                                    $self->{blocks}[0], $entry->num);
} # end AppleII::ProDOS::Directory::open

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
#   access:   The access attributes
#   auxtype:  The auxiliary type
#   block:    The key block for this file
#   blocks:   The number of blocks used by this file
#   created:  The creation date/time
#   modified: The date/time of last modification
#   name:     The filename
#   num:      The entry number of this entry
#   size:     The file size in bytes
#   storage:  The storage type
#   type:     The file type
#---------------------------------------------------------------------
AppleII::ProDOS->import(qw(packDate packName parseName parseType validName));
use integer;
use strict;
use vars '@ISA';

@ISA = 'AppleII::ProDOS::Members';

my %fields = (
    access      => 0xFF,
    auxtype     => 0xFFFF,
    block       => sub { not defined $_[0]{block} },
    blocks      => sub { not defined $_[0]{blocks} },
    created     => 0xFFFF,      # FIXME need better validator
    modified    => 0xFFFF,      # FIXME need better validator
    name        => \&validName,
    num         => sub { not defined $_[0]{num}  },
    size        => sub { not defined $_[0]{size} },
    type        => 0xFF,
);

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

    $self->{'_permitted'} = \%fields;
    if ($entry) {
        $self->{num} = $number;
        @{$self}{'storage', 'name'} = parseName($entry);
        @{$self}{qw(type block blocks size)} = unpack('x16Cv2V',$entry);
        $self->{size} &= 0xFFFFFF;  # Size is only 3 bytes long
        @{$self}{qw(access auxtype)} = unpack('x30Cv',$entry);

        $self->{created}  = substr($entry,0x18,4);
        $self->{modified} = substr($entry,0x21,4);
    } else {
        # Blank entry:
        $self->{created} = $self->{modified} = packDate(time);
    }
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

#---------------------------------------------------------------------
# Return the filetype as a string:

sub shortType
{
    parseType(shift->{type});
} # end AppleII::ProDOS::DirEntry::shortType

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
package AppleII::ProDOS::Members;
#
# Provides access functions for member variables.  This class is based
# on code from Tom Christiansen's FMTEYEWTK on OO Perl vs. C++.
#
# Only those member variables whose names are listed in the _permitted
# hash may be accessed.
#
# The value in the _permitted hash is used for validating the new
# value of a field.  The possible values are:
#   undef     No changes allowed (read-only)
#   CODE ref  Call CODE with our @_.  It returns true if OK.
#   scalar    New value must be an integer between 0 and _permitted
#---------------------------------------------------------------------

use Carp;
no strict;

sub AUTOLOAD
{
    my $self = $_[0];
    my $type = ref($self) or croak("$self is not an object");
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    unless (exists $self->{_permitted}{$name}) {
        # Ignore special methods like DESTROY:
        return undef if $name =~ /^[A-Z]+$/;
        croak("Can't access `$name' field in object of class $type");
    }
    if ($#_) {
        my $check = $self->{_permitted}{$name};
        my $ok;
        if (ref($check) eq 'CODE') {
            $ok = &$check;      # Pass our @_ to validator
        } elsif ($check) {
            $ok = ($_[1] =~ /^[0-9]+$/ and $_[1] >= 0 and $_[1] <= $check);
        } else {
            croak("Field `$name' of class $type is read-only");
        }
        return $self->{$name} = $_[1] if $ok;
        croak("Invalid value `$_[1]' for field `$name' of class $type");
    }
    return $self->{$name};
} # end AppleII::ProDOS::Members::AUTOLOAD

#=====================================================================
# Package Return Value:

1;

__END__

# Local Variables:
# tmtrack-file-task: "AppleII::ProDOS.pm"
# End:
