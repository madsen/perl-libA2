#---------------------------------------------------------------------
package AppleII::ProDOS;
#
# Copyright 1996 Christopher J. Madsen
#
# Author: Christopher J. Madsen <ac608@yfn.ysu.edu>
# Created: 26 Jul 1996
# Version: $Revision: 0.25 $ ($Date: 1996/08/19 04:48:06 $)
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
use AppleII::Disk 0.009;
use Carp;
use POSIX 'mktime';
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION $AUTOLOAD);

require Exporter;
@ISA = qw(AppleII::ProDOS::Members Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(
    pack_date pack_name parse_date parse_name parse_type shell_wc
    short_date valid_date valid_name a2_croak
);

my %vol_fields = (
    bitmap   => undef,
    disk     => undef,
    diskSize => undef,
    name     => undef,
);

# Methods to be passed along to the current directory:
my %dir_methods = (
    catalog  => undef,
    get_file => undef,
    new_dir  => undef,
    put_file => undef,
);

#=====================================================================
# Package Global Variables:

BEGIN
{
    # Convert RCS revision number to d.ddd format:
    ' $Revision: 0.25 $ ' =~ / (\d+)\.(\d{1,3})(\.[0-9.]+)? /
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
#   name:
#     The volume name of the disk
#---------------------------------------------------------------------
# Constructor for creating a new disk:
#
# Input:
#   name:
#     The volume name for the new disk
#   diskSize:
#     The size of the disk in blocks
#   filename:
#     The pathname of the image file you want to open
#   mode: (optional)
#     A string indicating how the image should be opened
#     See AppleII::Disk::new for details.
#     'rw' is always appended to the mode

sub new
{
    my ($type, $name, $diskSize, $filename, $mode) = @_;

    a2_croak("Invalid name `$name'") unless valid_name($name);

    my $disk = AppleII::Disk->new($filename, ($mode || '') . 'rw');
    $disk->blocks($diskSize);

    my $bitmap = AppleII::ProDOS::Bitmap->new($disk,6,$diskSize);

    my $self = {
        bitmap      => $bitmap,
        directories => [ AppleII::ProDOS::Directory->new(
            $name, $disk, [2 .. 5], $bitmap
        ) ],
        disk   => $disk,
        name   => $name,
        _dir_methods => \%dir_methods,
        _permitted => \%vol_fields,
    };

    $bitmap->write_disk;
    $self->{directories}[0]->write_disk;

    bless $self, $type;
} # end AppleII::ProDOS::new

#---------------------------------------------------------------------
# Constructor for opening an existing disk:
#
# There are two forms:
#   open(disk); or
#   open(filename, mode);
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

sub open
{
    my ($type, $disk, $mode) = @_;
    my $self = {
        _dir_methods => \%dir_methods,
        _permitted   => \%vol_fields,
    };
    $disk = AppleII::Disk->new($disk, $mode) unless ref $disk;
    $self->{disk} = $disk;

    my $volDir = $disk->read_block(2);

    my $storageType;
    ($storageType, $self->{name}) = parse_name(substr($volDir,0x04,16));
    croak('This is not a ProDOS disk') unless $storageType == 0xF;

    my ($startBlock, $diskSize) = unpack('x39v2',$volDir);
    $disk->blocks($diskSize);

    $self->{bitmap} =
      AppleII::ProDOS::Bitmap->open($disk,$startBlock,$diskSize);

    $self->{directories} = [
        AppleII::ProDOS::Directory->open($disk, 2, $self->{bitmap})
    ];
    $self->{diskSize} = $diskSize;

    bless $self, $type;
} # end AppleII::ProDOS::open

#---------------------------------------------------------------------
# Return the current directory:
#
# Returns:
#   The current AppleII::ProDOS::Directory

sub dir {
    shift->{directories}[-1];
} # end AppleII::ProDOS::dir

#---------------------------------------------------------------------
# Return or change the current path:
#
# Input:
#   newpath:  The path to change to
#
# Returns:
#   The current path (begins and ends with '/')

sub path
{
    my ($self, $newpath) = @_;

    if ($newpath) {
        # Change directory:
        my @directories = @{$self->{directories}};
        $#directories = 0 if $newpath =~ s!^/\Q$self->{name}\E/?!!i;
        pop @directories
            while $#directories and $newpath =~ s'^\.\.(?:/|$)''; #'
        my $dir;
        foreach $dir (split(/\//, $newpath)) {
            eval { push @directories, $directories[-1]->open_dir($dir) };
            croak("No such directory `$_[1]'") if $@ =~ /^No such directory/;
            die $@ if $@;
        }
        $self->{directories} = \@directories;
    } # end if changing path

    '/'.join('/',map { $_->{name} } @{$self->{directories}}).'/';
} # end AppleII::ProDOS::path

#---------------------------------------------------------------------
# Pass method calls along to the current directory:

sub AUTOLOAD
{
    my $self = $_[0];
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    unless (ref($self) and exists $self->{'_dir_methods'}{$name}) {
        # Try to access a field by that name:
        $AppleII::ProDOS::Members::AUTOLOAD = $AUTOLOAD;
        goto &AppleII::ProDOS::Members::AUTOLOAD;
    }

    shift @_; # Remove self
    $self->{directories}[-1]->$name(@_);
} # end AppleII::ProDOS::AUTOLOAD

#---------------------------------------------------------------------
# Like croak, but get out of all AppleII::ProDOS classes:

sub a2_croak
{
    local $Carp::CarpLevel = $Carp::CarpLevel;
    while ((caller $Carp::CarpLevel)[0] =~ /^AppleII::ProDOS/) {
        ++$Carp::CarpLevel;
    }
    &croak;
} # end AppleII::ProDOS::a2_croak

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

sub pack_date
{
    my ($minute,$hour,$day,$month,$year) = (localtime($_[0]))[1..5];
    pack('vC2', ($year<<9) + (($month+1)<<5) + $day, $minute, $hour);
} # end AppleII::ProDOS::pack_date

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

sub pack_name
{
    pack('Ca15',($_[0] << 4) + length($_[1]), uc $_[1]);
} # end AppleII::ProDOS::pack_name

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

sub parse_date
{
    my ($date, $minute, $hour) = unpack('vC2', $_[0]);
    return undef unless $date;
    my ($year, $month, $day) = ($date>>9, (($date>>5) & 0x0F), $date & 0x1F);
    mktime(0, $minute, $hour, $day, $month-1, $year);
} # end AppleII::ProDOS::parse_date

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

sub parse_name
{
    my $typeLen = ord $_[0];
    ($typeLen >> 4, substr($_[0],1,$typeLen & 0x0F));
} # end AppleII::ProDOS::parse_name

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

sub parse_type
{
    $filetypes[$_[0]];
} # end AppleII::ProDOS::parse_type

#---------------------------------------------------------------------
# Convert shell-type wildcards to Perl regexps:
#
# This is NOT a method; it's just a regular subroutine.
#
# Input:
#   The filename with optional wildcards
#
# Returns:
#   A Perl regexp

sub shell_wc
{
    '^' .
    join('',
         map { if (/\?/) {'.'} elsif (/\*/) {'.*'} else {quotemeta $_}}
         split(//,$_[0]));
} # end AppleII::ProDOS::shell_wc

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

sub short_date
{
    my ($date, $minute, $hour) = unpack('vC2', $_[0]);
    return "<No Date>      " unless $date;
    my ($year, $month, $day) = ($date>>9, (($date>>5) & 0x0F), $date & 0x1F);
    sprintf('%2d-%s-%02d %2d:%02d',$day,$months[$month-1],$year,$hour,$minute);
} # end AppleII::ProDOS::short_date

#---------------------------------------------------------------------
# Determine if a date is valid:
#
# May be called as a method or a normal subroutine.
#
# This is not a very strenuous check; it doesn't know that not all
# months have 31 days.  [FIXME]
#
# Input:
#   The date to check in ProDOS format (4 byte packed string)
#
# Returns:
#   0 if the date is invalid
#   1 if the date is zero (no date)
#   2 if the date is valid

sub valid_date
{
    return 1 if $_[-1] eq "\0\0\0\0"; # No date
    my ($date, $minute, $hour) = unpack('vC2', $_[-1]);
    my ($year, $month, $day) = ($date>>9, (($date>>5) & 0x0F), $date & 0x1F);
    return 0 if $minute > 59 or $hour > 23 or $year > 99
             or $month  > 12 or $month < 1 or $day  > 31 or $day < 1;
    2;                          # Valid date
} # end AppleII::ProDOS::valid_date

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

sub valid_name
{
    $_[-1] =~ /\A[a-z][a-z0-9.]{0,14}\Z(?!\n)/i;
} # end AppleII::ProDOS::valid_name

#=====================================================================
package AppleII::ProDOS::Bitmap;
#
# Member Variables:
#   bitmap:    The volume bitmap itself
#   blocks:    An array of the block numbers where the bitmap is stored
#   disk:      An AppleII::Disk
#   diskSize:  The number of blocks on the disk
#   free:      The number of free blocks
#---------------------------------------------------------------------

use Carp;
use strict;
use vars '@ISA';

@ISA = 'AppleII::ProDOS::Members';

# Map ProDOS bit order to Perl's vec():
my @adjust = (7, 5, 3, 1, -1, -3, -5, -7);

my %bit_fields = (
    diskSize => undef,
    free     => undef,
);

#---------------------------------------------------------------------
# Constructor for creating a new bitmap:
#
# All blocks are marked free, except for blocks 0 thru the end of the
# bitmap, which are marked used.
#
# Input:
#   disk:        The AppleII::Disk to use
#   startBlock:  The block number where the volume bitmap begins
#   diskSize:    The size of the disk in blocks

sub new
{
    my ($type, $disk, $startBlock, $diskSize) = @_;
    my $self = {
        bitmap     => ("\xFF" x int($diskSize / 8)),
        disk       => $disk,
        diskSize   => $diskSize,
        free       => $diskSize,
        _permitted => \%bit_fields,
    };
    bless $self, $type;
    $self->mark([ $diskSize-8 .. $diskSize-1], 1); # Mark odd blocks at end

    my @blocks;
    do {
        push @blocks, $startBlock++;
    } while ($diskSize -= 0x1000) > 0;

    $self->mark([ 0 .. @blocks[-1] ], 0); # Mark initial blocks as used

    $self->{bitmap} =
        $disk->pad_block($self->{bitmap},"\0",($#blocks+1) * 0x200);
    $self->{blocks} = \@blocks;
    $self->{free} = unpack('%32b*', $self->{bitmap});

    $self;
} # end AppleII::ProDOS::Bitmap::new

#---------------------------------------------------------------------
# Constructor for reading an existing bitmap:
#
# Input:
#   disk:        The AppleII::Disk to use
#   startBlock:  The block number where the volume bitmap begins
#   diskSize:    The size of the disk in blocks
#     STARTBLOCK & BLOCKS are optional.  If they are omitted, we get
#     the information from the volume directory.

sub open
{
    my ($type, $disk, $startBlock, $diskSize) = @_;
    my $self = {};
    $self->{disk} = $disk;
    $self->{'_permitted'} = \%bit_fields;
    unless ($startBlock and $diskSize) {
        my $volDir = $disk->read_block(2);
        ($startBlock, $diskSize) = unpack('v2',substr($volDir,0x27,4));
    }
    $self->{diskSize} = $diskSize;
    do {
        push @{$self->{blocks}}, $startBlock++;
    } while ($diskSize -= 0x1000) > 0;

    bless $self, $type;
    $self->read_disk;
    $self;
} # end AppleII::ProDOS::Bitmap::open

#---------------------------------------------------------------------
# Get some free blocks:
#
# Input:
#   count:  The number of blocks requested
#
# Returns:
#   A list of block numbers (which have been marked as used)
#   The empty list if there aren't enough free blocks

sub get_blocks
{
    my ($self, $count) = @_;
    return () if $count > $self->{free};
    my @blocks;
    my $bitmap = $self->{bitmap};
  BLOCK:
    while ($bitmap =~ m/([^\0])/g) {
        my ($offset, $byte) = (8*(pos($bitmap)-1), unpack('B8',$1));
        while ($byte =~ m/1/g) {
            push @blocks, $offset + pos($byte)-1;
            last BLOCK unless --$count;
        }
    } # end while BLOCK
    return () if $count;        # We couldn't find enough
    $self->mark(\@blocks,0);    # Mark blocks as in use
    @blocks;
} # end AppleII::ProDOS::Bitmap::get_blocks

#---------------------------------------------------------------------
# See if a block is free:
#
# Input:
#   block:  The block number to check
#
# Returns:
#   True if the block is free

sub is_free
{
    my ($self, $block) = @_;
    croak("No block $block") if $block < 0 or $block >= $self->{diskSize};
    vec($self->{bitmap}, $block + $adjust[$block % 8],1);
} # end AppleII::ProDOS::Bitmap::is_free

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
    $self->{free} += ($mark ? 1 : -1) * ($#$blocks + 1);
} # end AppleII::ProDOS::Bitmap::is_free

#---------------------------------------------------------------------
# Read bitmap from disk:

sub read_disk
{
    my $self = shift;
    $self->{bitmap} = $self->{disk}->read_blocks($self->{blocks});
    $self->{free}   = unpack('%32b*', $self->{bitmap});
} # end AppleII::ProDOS::Bitmap::read_disk

#---------------------------------------------------------------------
# Return the block number where the bitmap begins:

sub start_block
{
    shift->{blocks}[0];
} # end AppleII::ProDOS::Bitmap::start_block

#---------------------------------------------------------------------
# Write bitmap to disk:

sub write_disk
{
    my $self = shift;
    $self->{disk}->write_blocks($self->{blocks}, $self->{bitmap});
} # end AppleII::ProDOS::Bitmap::write_disk

#=====================================================================
package AppleII::ProDOS::Directory;
#
# Member Variables:
#   access:
#     The access attributes for this directory
#   bitmap:
#     The AppleII::ProDOS::Bitmap for the disk
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
#   reserved:
#     The contents of the reserved section (8 byte string)
#   type:
#     0xF for a volume directory, 0xE for a subdirectory
#   version:
#     The contents of the VERSION & MIN_VERSION (2 byte string)
#
# For subdirectories:
#   parent:     The block number in the parent directory where our entry is
#   parentNum:  Our entry number within that block of the parent directory
#   fixParent:  True means our parent entry needs to be updated
#
# We also use the os_openDirs field of the disk to keep track of open
# directories.  It contains a hash of Directory objects indexed by key
# block.  The constructors automatically add the new objects to the
# hash, and the destructor removes them.
#---------------------------------------------------------------------

AppleII::ProDOS->import(qw(a2_croak pack_date pack_name parse_name
                           short_date valid_date valid_name));
use Carp;
use strict;
use vars '@ISA';

@ISA = 'AppleII::ProDOS::Members';

my %dir_fields = (
    access      => 0xFF,
    created     => \&valid_date,
    name        => \&valid_name,
    type        => undef,
    version     => undef,
);

#---------------------------------------------------------------------
# Constructor for creating a new directory:
#
# You must supply parent & parentNum when creating a subdirectory.
#
# Input:
#   name:       The name of the new directory
#   disk:       An AppleII::Disk
#   blocks:     A block number or array of block numbers for the directory
#   bitmap:     The AppleII::ProDOS::Bitmap for the disk
#   parent:     The block number in the parent directory where our entry is
#   parentNum:  Our entry number within that block of the parent directory

sub new
{
    my ($type, $name, $disk, $blocks, $bitmap, $parent, $parentNum) = @_;

    a2_croak("Invalid name `$name'") unless valid_name($name);

    my $self = {
        access  => 0xE3,
        bitmap  => $bitmap,
        blocks  => $blocks,
        disk    => $disk,
        entries => [],
        name    => $name,
        version => "\0\0",
        created => pack_date(time),
        _permitted => \%dir_fields,
    };

    if ($parent) {
        $self->{type}      = 0xE; # Subdirectory
        $self->{parent}    = $parent;
        $self->{parentNum} = $parentNum;
        $self->{reserved}  = "\x75\x23\x00\xC3\x27\x0D\x00\x00";
    } else {
        $self->{type} = 0xF;    # Volume directory
        $self->{reserved} = "\0" x 8; # 8 bytes reserved
    } # end else volume directory

    bless $self, $type;
    $disk->{os_openDirs}{$blocks->[0]} = $self;
    $self;
} # end AppleII::ProDOS::Directory::new

#---------------------------------------------------------------------
# Constructor for reading an existing directory:
#
# Input:
#   disk:       An AppleII::Disk
#   block:      The block number where the directory begins
#   bitmap:     The AppleII::ProDOS::Bitmap for the disk

sub open
{
    my ($type, $disk, $block, $bitmap) = @_;
    my $self = {
        bitmap     => $bitmap,
        disk       => $disk,
        _permitted => \%dir_fields,
    };

    bless $self, $type;
    $disk->{os_openDirs}{$block} = $self;
    $self->read_disk($block);
    $self;
} # end AppleII::ProDOS::Directory::open

#---------------------------------------------------------------------
# Destructor:
#
# Removes the directory from the hash of open directories.

sub DESTROY
{
    my $self = shift;
    delete $self->{disk}{os_openDirs}{$self->{blocks}[0]};
} # end AppleII::ProDOS::Directory::DESTROY

#---------------------------------------------------------------------
# Add entry:
#
# Dies if the entry can't be added.
#
# Input:
#   entry:  An AppleII::ProDOS::DirEntry

sub add_entry
{
    my ($self,$entry) = @_;

    a2_croak($entry->name . ' already exists')
        if $self->find_entry($entry->name);

    my $entries = $self->{entries};

    my $i;
    for ($i=0; $i <= $#$entries; ++$i) {
        last if $entries->[$i]{num} > $i+1;
    }

    if ($i+1 >= 0xD * scalar @{$self->{blocks}}) {
        a2_croak('Volume full') unless $self->{type} == 0xE; # Subdirectory
        my @blocks = $self->{bitmap}->get_blocks(1);
        a2_croak('Volume full') unless @blocks;
        push @{$self->{blocks}}, @blocks;
        $self->{fixParent} = 1;
    } # end if directory full

    $entry->{num} = $i+1;
    splice @$entries, $i, 0, $entry;
} # end AppleII::ProDOS::Directory::add_entry

#---------------------------------------------------------------------
# Return the directory listing and free space information:
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
                           $entry->name, $entry->short_type, $entry->blksUsed,
                           short_date($entry->modified),
                           short_date($entry->created),
                           $entry->size, $entry->auxtype);
    } # end foreach entry

    my $bitmap = $self->{bitmap};
    my ($free, $total, $used) = ($bitmap->free, $bitmap->diskSize);
    $used = $total - $free;

    $result .
        "Blocks free: $free     Blocks used: $used     Total blocks: $total\n";
} # end AppleII::ProDOS::Directory::catalog

#---------------------------------------------------------------------
# Return the list of entries:
#
# Returns:
#   A list of AppleII::ProDOS::DirEntry objects

sub entries
{
    @{shift->{entries}};
} # end AppleII::ProDOS::Directory::entries

#---------------------------------------------------------------------
# Find an entry:
#
# Input:
#   filename:  The filename to match
#
# Returns:
#   The entry representing that filename

sub find_entry
{
    my ($self, $filename) = @_;
    $filename = uc $filename;
    (grep {uc($_->name) eq $filename} @{$self->{'entries'}})[0];
} # end AppleII::ProDOS::Directory::find_entry

#---------------------------------------------------------------------
# Read a file:
#
# Input:
#   file:
#     The name of the file to read, OR
#     An AppleII::ProDOS::DirEntry object representing a file
#
# Returns:
#   A new AppleII::ProDOS::File object for the file

sub get_file
{
    my ($self, $filename) = @_;

    my $entry = (ref($filename)
                 ? $filename
                 : ($self->find_entry($filename)
                    or a2_croak("No such file `$filename'")));

    AppleII::ProDOS::File->open($self->{disk}, $entry);
} # end AppleII::ProDOS::Directory::get_file

#---------------------------------------------------------------------
# List files matching a regexp:
#
# Input:
#   pattern:
#     The Perl regexp to match
#     (AppleII::ProDOS::shell_wc converts shell-type wildcards to regexps)
#   filter: (optional)
#     A subroutine to run against the entries
#     It must return a true value for the file to be accepted.
#     There are three special values:
#       undef   Match anything
#       'DIR'   Match only directories
#       '!DIR'  Match anything but directories
#
# Returns:
#   A list of filenames matching the pattern

sub list_matches
{
    my ($self, $pattern, $filter) = @_;
    $filter = \&is_dir   if $filter eq 'DIR';
    $filter = \&isnt_dir if $filter eq '!DIR';
    $filter = \&true     unless $filter;
    map { ($_->name =~ /$pattern/i and &$filter($_))
          ? $_->name
          : () }
        @{$self->{'entries'}};
} # end AppleII::ProDOS::Directory::list_matches

sub is_dir   { $_[0]->type == 0x0F } # True if entry is directory
sub isnt_dir { $_[0]->type != 0x0F } # True if entry is not directory
sub true     { 1 }                   # Accept anything

#---------------------------------------------------------------------
# Create a subdirectory:
#
# Input:
#   dir:     The name of the subdirectory to create
#   size:    The number of entries the directory should hold
#            The default is to create a 1 block directory
#
# Returns:
#   The DirEntry object for the new directory

sub new_dir
{
    my ($self, $dir, $size) = @_;

    a2_croak("Invalid name `$dir'") unless valid_name($dir);

    $size = 1 unless $size;
    $size = int(($size + 0xD) / 0xD); # Compute # of blocks (+ dir header)

    my @blocks = $self->{bitmap}->get_blocks($size)
        or a2_croak("Not enough free space");

    my $entry = AppleII::ProDOS::DirEntry->new;

    eval {
        $entry->storage(0xD);   # Directory
        $entry->name($dir);
        $entry->type(0x0F);     # Directory
        $entry->block($blocks[0]);
        $entry->blksUsed($#blocks + 1);
        $entry->size(0x200 * ($#blocks + 1));

        $self->add_entry($entry);
        my $subdir = AppleII::ProDOS::Directory->new(
            $dir, $self->{disk}, \@blocks, $self->{bitmap},
            $self->{blocks}[int($entry->num / 0xD)], int($entry->num % 0xD)+1
        );

        $subdir->write_disk;
        $self->write_disk;
        $self->{bitmap}->write_disk;
    }; # end eval
    if ($@) {
        my $error = $@;         # Clean up after error
        $self->read_disk;
        $self->{bitmap}->read_disk;
        die $error;
    } # end if error while creating directory

    $entry;
} # end AppleII::ProDOS::Directory::new_dir

#---------------------------------------------------------------------
# Open a subdirectory:
#
# Input:
#   dir:  The name of the subdirectory to open
#
# Returns:
#   A new AppleII::ProDOS::Directory object for the subdirectory

sub open_dir
{
    my ($self, $dir) = @_;

    my $entry = $self->find_entry($dir)
        or a2_croak("No such directory `$dir'");

    AppleII::ProDOS::Directory->open($self->{disk}, $entry->block,
                                     $self->{bitmap});
} # end AppleII::ProDOS::Directory::open_dir

#---------------------------------------------------------------------
# Add a new file to the directory:
#
# Input:
#   file:    The AppleII::ProDOS::File to add

sub put_file
{
    my ($self, $file) = @_;

    eval {
        $file->allocate_space($self->{bitmap});
        $self->add_entry($file);
        $file->write_disk($self->{disk});
        $self->write_disk;
        $self->{bitmap}->write_disk;
    };
    if ($@) {
        my $error = $@;
        # Clean up after failure:
        $self->read_disk;
        $self->{bitmap}->read_disk;
        die $error;
    }
} # end AppleII::ProDOS::Directory::put_file

#---------------------------------------------------------------------
# Read directory from disk:

sub read_disk
{
    my ($self, $block) = @_;
    $block = $self->{blocks}[0] unless $block;

    my (@blocks,@entries);
    my $disk = $self->{disk};
    my $entry = 0;
    while ($block) {
        push @blocks, $block;
        my $data = $disk->read_block($block);
        $block = unpack('v',substr($data,0x02,2)); # Pointer to next block
        substr($data,0,4) = '';                    # Remove block pointers
        while ($data) {
            my ($type, $name) = parse_name($data);
            if (($type & 0xE) == 0xE) {
                # Directory header
                $self->{name} = $name;
                $self->{type} = $type;
                $self->{reserved} = substr($data, 0x14-4,8);
                $self->{created} = substr($data, 0x1C-4,4);
                $self->{version} = substr($data, 0x20-4,2);
                $self->{access}  = ord substr($data, 0x22-4,1);
                if ($type == 0xE) {
                    # For subdirectory, read parent pointers
                    @{$self}{qw(parent parentNum)} =
                        unpack('vC',substr($data,0x27-4,3));
                } # end if subdirectory
            } elsif ($type) {
                # File entry
                push @entries, AppleII::ProDOS::DirEntry->new($entry, $data);
            }
            substr($data,0,0x27) = ''; # Remove record
            ++$entry;
        } # end while more records
    } # end if rebuilding block list

    @{$self}{qw(blocks entries)}  = (\@blocks, \@entries);
} # end AppleII::ProDOS::Directory::read_disk

#---------------------------------------------------------------------
# Write directory to disk:

sub write_disk
{
    my ($self) = @_;

    my $disk    = $self->{disk};
    my @blocks  = @{$self->{blocks}};
    my @entries = @{$self->{'entries'}};
    my $keyBlock = $blocks[0];

    if ($self->{fixParent}) {
        delete $self->{fixParent};
        my $data = $disk->read_block($self->{parent});
        my $entry = 4 + 0x27*($self->{parentNum}-1);
        substr($data, $entry + 0x11, 7) =
            pack('v2VX', $keyBlock, scalar(@blocks), 0x200 * scalar(@blocks));
        # FIXME update modified date?
        $disk->write_block($self->{parent}, $data);
        my $parentBlock = unpack('v', substr($data,$entry + 0x25, 2));
        $disk->{os_openDirs}{$parentBlock}->read_disk
            if $disk->{os_openDirs}{$parentBlock};
    } # end if parent entry needs updating

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
                $data .= pack_name(@{$self}{'type','name'});
                $data .= $self->{reserved};
                $data .= $self->{created};
                $data .= $self->{version};
                $data .= chr $self->{access};
                $data .= "\x27\x0D"; # Entry length, entries per block
                $data .= pack('v',$#entries+1);
                if ($self->{type} == 0xF) {
                    my $bitmap = $self->{bitmap};
                    $data .= pack('v2',$bitmap->start_block,$bitmap->diskSize);
                } else {
                    $data .= pack('vCC',@{$self}{'parent','parentNum'},
                                  0x27); # Parent entry length
                } # end else subdirectory
            } # end else if directory header
            ++$entry;
        } # end while more room in block
        $disk->write_block($blocks[$i],$data."\0");
    } # end for each directory block
} # end AppleII::ProDOS::Directory::write_disk

#=====================================================================
package AppleII::ProDOS::DirEntry;
#
# Member Variables:
#   access:   The access attributes
#   auxtype:  The auxiliary type
#   block:    The key block for this file
#   blksUsed: The number of blocks used by this file
#   created:  The creation date/time
#   modified: The date/time of last modification
#   name:     The filename
#   num:      The entry number of this entry
#   size:     The file size in bytes
#   storage:  The storage type
#   type:     The file type
#   version:  The contents of the VERSION & MIN_VERSION (2 byte string)
#---------------------------------------------------------------------
AppleII::ProDOS->import(qw(pack_date pack_name parse_name parse_type
                           valid_date valid_name));
use integer;
use strict;
use vars '@ISA';

@ISA = 'AppleII::ProDOS::Members';

my %de_fields = (
    access      => 0xFF,
    auxtype     => 0xFFFF,
    block       => sub { not defined $_[0]{block}    },
    blksUsed    => sub { not defined $_[0]{blksUsed} },
    created     => \&valid_date,
    modified    => \&valid_date,
    name        => \&valid_name,
    num         => sub { not defined $_[0]{num}     },
    size        => sub { not defined $_[0]{size}    },
    storage     => sub { not defined $_[0]{storage} },
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

    $self->{'_permitted'} = \%de_fields;
    if ($entry) {
        $self->{num} = $number;
        @{$self}{'storage', 'name'} = parse_name($entry);
        @{$self}{qw(type block blksUsed size)} = unpack('x16Cv2V',$entry);
        $self->{size} &= 0xFFFFFF;  # Size is only 3 bytes long
        @{$self}{qw(access auxtype)} = unpack('x30Cv',$entry);

        $self->{created}  = substr($entry,0x18,4);
        $self->{modified} = substr($entry,0x21,4);
        $self->{version}  = substr($entry,0x1C,2);
    } else {
        # Blank entry:
        $self->{created} = $self->{modified} = pack_date(time);
        @{$self}{qw(access auxtype type version)} =
            (0xE3, 0x0000, 0x00, "\0\0");
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
    my $data = pack_name(@{$self}{'storage', 'name'});
    $data .= pack('Cv2VX',@{$self}{qw(type block blksUsed size)});
    $data .= $self->{created} . $self->{version};
    $data .= pack('Cv',@{$self}{qw(access auxtype)});
    $data .= $self->{modified};
    $data .= pack('v',$keyBlock);
} # end AppleII::ProDOS::DirEntry::packed

#---------------------------------------------------------------------
# Return the filetype as a string:

sub short_type
{
    parse_type(shift->{type});
} # end AppleII::ProDOS::DirEntry::short_type

#=====================================================================
package AppleII::ProDOS::File;
#
# Member Variables:
#   data:         The contents of the file
#   indexBlocks:  For tree files, the number of subindex blocks needed
#
# Private Members (for communication between allocate_space & write_disk):
#   blocks:       The list of data blocks allocated for this file
#   indexBlocks:  For tree files, the list of subindex blocks
#---------------------------------------------------------------------

AppleII::ProDOS->import(qw(a2_croak valid_date valid_name));
use Carp;
use vars qw(@ISA);

@ISA = 'AppleII::ProDOS::DirEntry';

my %fil_fields = (
    access      => 0xFF,
    auxtype     => 0xFFFF,
    blksUsed    => undef,
    created     => \&valid_date,
    data        => undef,
    modified    => \&valid_date,
    name        => \&valid_name,
    size        => undef,
    type        => 0xFF,
);

#---------------------------------------------------------------------
# Constructor for creating a new file:
#
# Input:
#   name:  The filename
#   data:  The contents of the file

sub new
{
    my ($type, $name, $data) = @_;
    a2_croak("Invalid name `$name'") unless valid_name($name);
    my $self = {
        access     => 0xE3,
        auxtype    => 0,
        created    => "\0\0\0\0",
        data       => $data,
        modified   => "\0\0\0\0",
        name       => $name,
        size       => length($data),
        type       => 0,
        version    => "\0\0",
        _permitted => \%fil_fields
    };

    my $blksUsed = int((length($data) + 0x1FF) / 0x200);
    $self->{storage} = 2;       # Assume sapling file
    if ($blksUsed > 0x100) {
        $self->{storage} = 3;   # Need extra index blocks for tree file
        $blksUsed += $self->{indexBlocks} = int(($blksUsed + 0xFF) / 0x100);
    }
    if ($blksUsed > 1) { ++$blksUsed        } # Tree or sapling file
    else             { $self->{storage} = 1 } # Seedling file

    $self->{blksUsed} = $blksUsed;

    bless $self, $type;
} # end AppleII::ProDOS::File::new

#---------------------------------------------------------------------
# Open a file:
#
# Input:
#   disk:   The disk to read
#   entry:  The AppleII::ProDOS::DirEntry that describes the file

sub open
{
    my ($type, $disk, $entry) = @_;
    my $self = { _permitted => \%fil_fields };
    my @fields = qw(access auxtype blksUsed created modified name size
                    storage type version);
    @{$self}{@fields} = @{$entry}{@fields};

    my ($storage, $keyBlock, $blksUsed, $size) =
        @{$entry}{qw(storage block blksUsed size)};

    my $data;
    if ($storage == 1) {
        $data = $disk->read_block($keyBlock);
    } elsif ($storage == 2) {
        my $index = AppleII::ProDOS::Index->open($disk,$keyBlock,$blksUsed-1);
        $data = $disk->read_blocks($index->blocks);
    } elsif ($storage == 3) {
        my $blksUsed    = int(($size + 0x1FF) / 0x200);
        my $indexBlocks = int(($blksUsed + 0xFF) / 0x100);
        my $index = AppleII::ProDOS::Index->open($disk,$keyBlock,$indexBlocks);
        my (@blocks,$block);
        foreach $block (@{$index->blocks}) {
            my $subindex = AppleII::ProDOS::Index->open($disk,$block);
            push @blocks,@{$subindex->blocks};
        }
        $#blocks = $blksUsed-1; # Use only the first $blksUsed blocks
        $data = $disk->read_blocks(\@blocks);
        $self->{indexBlocks} = $indexBlocks;
    } else {
        croak("Unsupported storage type $storage");
    }

    substr($data, $size) = '' if length($data) > $size;
    $self->{'data'} = $data;

    bless $self, $type;
} # end AppleII::ProDOS::File::open

#---------------------------------------------------------------------
# Allocate space for the file:
#
# Input:
#   bitmap:  The AppleII::ProDOS::Bitmap we should use
#
# Input Variables:
#   indexBlocks:  The number of subindex blocks needed
#
# Output Variables:
#   blocks:       The list of data blocks allocated
#   indexBlocks:  The list of subindex blocks allocated

sub allocate_space
{
    my ($self, $bitmap) = @_;

    my @blocks = $bitmap->get_blocks($self->{blksUsed})
        or a2_croak("Not enough free space");

    my $storage = $self->{storage};

    $self->{block} = @blocks[0];

    shift @blocks if $storage > 1; # Remove index block from list

    if ($storage == 3) {
        $self->{indexBlocks} = [ splice @blocks, 0, $self->{indexBlocks} ];
    }

    croak("Unsupported storage type $storage") unless $storage < 4;

    $self->{blocks} = \@blocks;
} # end AppleII::ProDOS::File::allocate_space

#---------------------------------------------------------------------
# Return the file's contents as text:
#
# Returns:
#   The file's contents with hi bits stripped and CRs converted to \n

sub as_text
{
    my $self = shift;
    my $data = $self->{data};
    $data =~ tr/\r\x8D\x80-\xFF/\n\n\x00-\x7F/;
    $data;
} # end AppleII::ProDOS::File::as_text

#---------------------------------------------------------------------
# Write the file to disk:
#
# You must have already called allocate_space.
#
# Input:
#   disk:  The disk to write to
#
# Input Variables:
#   blocks:       The list of data blocks allocated
#   indexBlocks:  The list of subindex blocks allocated
#
# Output Variables:
#   indexBlocks:  The number of subindex blocks needed

sub write_disk
{
    my ($self, $disk) = @_;

    $disk->write_blocks($self->{blocks}, $self->{'data'}, "\0");

    my $storage = $self->{storage};
    if ($storage == 2) {
        my $index = AppleII::ProDOS::Index->new($disk,
                                                @{$self}{qw(block blocks)});
        $index->write_disk;
    } elsif ($storage == 3) {
        my $index =
          AppleII::ProDOS::Index->new($disk, @{$self}{qw(block indexBlocks)});
        $index->write_disk;
        my @blocks = @{$self->{blocks}};
        my $block;
        foreach $block (@{$self->{indexBlocks}}) {
            $index = AppleII::ProDOS::Index->new($disk, $block,
                                                 [splice(@blocks,0,0x100)]);
            $index->write_disk;
        }
        $self->{indexBlocks} = $#{$self->{indexBlocks}};
    } # end elsif tree file

    delete $self->{blocks};
} # end AppleII::ProDOS::File::write_disk

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
use vars '@ISA';

@ISA = 'AppleII::ProDOS::Members';

my %in_fields = (
    blocks => undef,
);

#---------------------------------------------------------------------
# Constructor for creating a new index block:
#
# Input:
#   disk:    An AppleII::Disk
#   block:   The block number of the index block
#   blocks:  The list of blocks that are pointed to by this block

sub new
{
    my ($type, $disk, $block, $blocks) = @_;
    my $self = {
        disk       => $disk,
        block      => $block,
        blocks     => $blocks,
        _permitted => \%in_fields,
    };

    bless $self, $type;
} # end AppleII::ProDOS::Index::new

#---------------------------------------------------------------------
# Constructor for reading an existing index block:
#
# Input:
#   disk:   An AppleII::Disk
#   block:  The block number to read
#   count:  The number of blocks that are pointed to by this block
#           (optional; default is 256)

sub open
{
    my ($type, $disk, $block, $count) = @_;
    my $self = {};
    $self->{disk} = $disk;
    $self->{block} = $block;
    $self->{'_permitted'} = \%in_fields;

    bless $self, $type;
    $self->read_disk($count);
    $self;
} # end AppleII::ProDOS::Index::open

#---------------------------------------------------------------------
# Read contents of index block from disk:
#
# Input:
#   count:
#     The number of blocks that are pointed to by this block
#     (optional; default is 256)

sub read_disk
{
    my ($self, $count) = @_;
    $count = 0x100 unless $count;
    my @dataLo = unpack('C*',$self->{disk}->read_block($self->{block}));
    my @dataHi = splice @dataLo, 0x100;
    my @blocks;

    while (--$count >= 0) {
        push @blocks, shift(@dataLo) + 0x100 * shift(@dataHi);
    }

    $self->{blocks} = \@blocks;
} # end AppleII::ProDOS::Index::read_disk

#---------------------------------------------------------------------
# Write bitmap to disk:

sub write_disk
{
    my $self = shift;
    my $disk = $self->{disk};

    my ($dataLo, $dataHi);
    $dataLo = $dataHi = pack('v*',@{$self->{blocks}});
    $dataLo =~ s/([\s\S])[\s\S]/$1/g; # Keep just the low byte
    $dataHi =~ s/[\s\S]([\s\S])/$1/g; # Keep just the high byte

    $disk->write_block($self->{block},
                       $disk->pad_block($dataLo,"\0",0x100) . $dataHi,
                       "\0");
} # end AppleII::ProDOS::Index::write_disk

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
use vars '$AUTOLOAD';

sub AUTOLOAD
{
    my $self = $_[0];
    my $type = ref($self) or croak("$self is not an object");
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    my $field = $name;
    $field =~ s/_([a-z])/\u$1/g; # squash underlines into mixed case
    unless (exists $self->{'_permitted'}{$field}) {
        # Ignore special methods like DESTROY:
        return undef if $name =~ /^[A-Z]+$/;
        croak("Can't access `$name' field in object of class $type");
    }
    if ($#_) {
        my $check = $self->{'_permitted'}{$field};
        my $ok;
        if (ref($check) eq 'CODE') {
            $ok = &$check;      # Pass our @_ to validator
        } elsif ($check) {
            $ok = ($_[1] =~ /^[0-9]+$/ and $_[1] >= 0 and $_[1] <= $check);
        } else {
            croak("Field `$name' of class $type is read-only");
        }
        return $self->{$field} = $_[1] if $ok;
        croak("Invalid value `$_[1]' for field `$name' of class $type");
    }
    return $self->{$field};
} # end AppleII::ProDOS::Members::AUTOLOAD

#=====================================================================
# Package Return Value:

1;

__END__

=head1 NAME

AppleII::ProDOS - Access files on Apple II ProDOS disk images

=head1 SYNOPSIS

    use AppleII::ProDOS;
    my $vol = AppleII::ProDOS->open('image.dsk'); # Open an existing disk
    print $vol->catalog;                  # List files in volume directory
    my $file = $vol->get_file('Startup'); # Read file from disk
    $vol->path('Subdir');                 # Move into a subdirectory
    $vol->put_file($file);                # And write it back there

=head1 AUTHOR

Christopher J. Madsen E<lt>F<ac608@yfn.ysu.edu>E<gt>

=cut

# Local Variables:
# tmtrack-file-task: "LibA2: AppleII::ProDOS.pm"
# End:
