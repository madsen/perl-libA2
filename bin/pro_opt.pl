#!perl
#---------------------------------------------------------------------
# $Id: pro_opt.pl,v 0.3 1996/08/19 04:50:18 Madsen Exp $
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

use AppleII::ProDOS 0.025;
use strict;

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

# Local Variables:
# tmtrack-file-task: "LibA2: pro_opt.pl"
# End:
