#! /usr/bin/perl
#---------------------------------------------------------------------
# $Id$
# Copyright 1996 Christopher J. Madsen
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Optimize a ProDOS disk image
#---------------------------------------------------------------------

use AppleII::ProDOS 0.04;
use strict;

our $VERSION = '0.04';

my ($file1, $file2) = @ARGV;

my $vol1 = AppleII::ProDOS->open($file1);
my $vol2 = AppleII::ProDOS->new($vol1->name, $vol1->diskSize, $file2);

# Copy boot blocks:
$vol2->disk->write_blocks([0 .. 1], $vol1->disk->read_blocks([0 .. 1]));

# Copy creation date:
$vol2->dir->created($vol1->dir->created);
$vol2->dir->write_disk;

mirror($vol1->dir->entries);

exit;

#---------------------------------------------------------------------
sub mirror
{
    my $path = $vol1->path;
    my $entry;
    foreach $entry (@_) {
        if ($entry->short_type eq 'DIR') {
            print "Creating $path" . $entry->name . "\n";
            $vol1->path($entry->name);
            my $newEntry = $vol2->new_dir($entry->name,
                                          scalar $vol1->dir->entries);
            $newEntry->created($entry->created);
            $newEntry->modified($entry->modified);
            $vol2->dir->write_disk;
            $vol2->path($entry->name);
            $vol2->dir->created($entry->created);
            mirror($vol1->dir->entries);
            $vol1->path('..');
            $vol2->path('..');
        } else {
            print "Copying $path" . $entry->name . "\n";
            $vol2->put_file($vol1->get_file($entry));
        }
    }
} # end mirror

__END__

=head1 NAME

pro_opt - Optimize an Apple II ProDOS disk image file

=head1 SYNOPSIS

B<pro_opt> IMAGE-FILE OUTPUT-FILE

=head1 DESCRIPTION

B<pro_opt> eliminates wasted space from a disk image file containing
an Apple II ProDOS volume.  It does this by creating a new disk image
file and copying all files from the old image to the new one.  Any
un-allocated blocks are eliminated from the new image file.

Note that some emulators cannot deal with image files that are smaller
than their nominal size.  That is, they expect a 280 block disk image
file to be 143,360 bytes long.  B<pro_opt> should not be used with
such emulators.

=head1 REQUIREMENTS

B<pro_opt> requires the modules AppleII::ProDOS and AppleII::Disk,
which are included with LibA2.

=head1 BUGS

Sparse files become non-sparse in the new disk image.  This may cause
the file to not fit.

There are no other known bugs, but you should keep a copy of your old image
file until you're sure the optimized image file works properly.

=head1 AUTHOR

Christopher J. Madsen E<lt>F<cjm@pobox.com>E<gt>

=cut

# Local Variables:
# tmtrack-file-task: "LibA2: pro_opt.pl"
# End:
