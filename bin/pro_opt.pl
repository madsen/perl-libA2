#!perl
#---------------------------------------------------------------------
# $Id: pro_opt.pl,v 0.1 1996/08/12 17:50:28 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# Optimize a ProDOS disk image
#---------------------------------------------------------------------

use AppleII::ProDOS 0.016;
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
            $vol2->new_dir($entry->name, scalar $vol1->dir->entries);
            my $newEntry = $vol2->dir->find_entry($entry->name);
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
            $vol2->put_file($vol1->get_file($entry->name));
        }
    }
} # end mirror
