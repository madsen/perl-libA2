#! /usr/bin/perl
#---------------------------------------------------------------------
# $Id: README.PL,v 1.8 2005/01/15 05:34:34 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# Create the README file for LibA2
#---------------------------------------------------------------------

use Text::Tabs;

# Read version number from Makefile.PL:

my $version;
open(PL, "<Makefile.PL") or die;
while (<PL>) {
    $version = $1, last if /^\s* VERSION\s* => \s* '(.+?)'/x;
}
close PL;
die unless defined $version;

# Generate README:

open(STDOUT,'>README') or die;
binmode STDOUT;

print "LibA2\tRelease $version\n";
print <<'EOT';
Copyright 1996 Christopher J. Madsen

LibA2 provides both end-user utilities and library modules for
accessing files on Apple II ProDOS disk images for use with most Apple
II emulators.

This is a BETA release of LibA2.  There's some documentation, but it's
not complete.  If you want to see the rest of the documentation, then
send email!  Otherwise, I'll probably never get around to writing it.
Until then, use the source, Luke!  There are still probably some bugs,
and the interfaces might still change.  Use at your own risk.  Keep a
recent backup handy.  Wait sixty minutes before swimming.

All this having been said, I'm not aware of any serious bugs in LibA2
(besides the ones listed in the BUGS section below).  Good luck!
I would very much like to hear from everyone who tries LibA2.  The
more comments I get, the more likely I am to do more work on it.
Please send comments, questions, bug reports, and patches to me.
You'll find my email address at the end of this file.

EOT
#'

print 'The included utilities are:';

list_util('prodos.pl');
print <<'EOT';
	`prodos.pl' is the main end-user utility.  It provides a
	Unix-style shell for accessing ProDOS volumes.  This allows
	you to list the contents of disk images, create
	subdirectories, and copy files to & from disk images.  If you
	have installed the Term::ReadKey and Term::ReadLine modules,
	the shell will have better editing, command & filename
	completion, and a command history.

	The parameters for prodos.pl are:
		prodos IMAGE_FILE
EOT
#`
list_util('pro_fmt.pl');
print <<'';
	`pro_fmt.pl' creates blank ProDOS disk images.  The images are
	NOT bootable, because they lack the necessary code in the boot
	blocks.  You can copy blocks 0 and 1 from a bootable disk to
	fix this.  The parameters for pro_fmt.pl are:
		pro_fmt VOLUME_NAME  SIZE_IN_BLOCKS  IMAGE_FILE
	This is likely to change in the future.

#`
list_util('pro_opt.pl');
print <<'';
	`pro_opt.pl' removes unused space from ProDOS disk images.  This
	is most useful for reducing the size of hard disk images.  It
	doesn't use any form of compression; it simply moves
	everything to the beginning of the disk, squashing out empty
	space caused by deleting files.  Be careful with this, as it's
	likely to have some bugs left.  The parameters for pro_opt.pl are:
		pro_opt SOURCE_IMAGE_FILE  DESTINATION_IMAGE_FILE

#`
list_util('awp2txt.pl');
print <<'';
	`awp2txt.pl' converts AppleWorks word processor files into text
	files.  This is a bit out of place in LibA2, because it has
	nothing to do with disk images, but I included it because
	users of LibA2 may find it useful.  The parameters for awp2txt are:
		awp2txt FILE ...

#`
list_util('var_display.pl');
print <<'';
	`var_display.pl' lists the contents of an Applesoft BASIC VAR file.
	Currently, it can only display string variables and string arrays.
	Like awp2txt, you must first extract the VAR file from the disk
	image.  The parameters for var_display are:
		var_display FILE

#`
print <<'EOT';

For people interested in writing their own utilities in Perl, LibA2
provides Perl 5 modules that supply classes for accessing ProDOS disk
images.  DOS 3.3 disks are not currently supported (except by
AppleII::Disk, which doesn't care what kind of data is on the disk).

EOT
#')

print "The included modules are:";

list_mod('AppleII/Disk.pm');
print <<'';
	`AppleII::Disk' provides block-level access to disk images.
	It's useful because there are two main formats for Apple disk
	images:  ProDOS order and DOS 3.3 order.  These formats do not
	refer to the operating system used on the disk, but to the
	order in which the data appears.  AppleII::Disk takes care of
	the differences for you.

#`
list_mod('AppleII/ProDOS.pm');
print <<'';
	`AppleII::ProDOS' provides tools for accessing files on ProDOS
	disk images.  `prodos.pl' is basically just a wrapper around
	AppleII::ProDOS.

#'
print <<EOT;

CHANGES
    Here's what's new in version $version of LibA2:
    (See the file \`Changes\' for the full revision history.)
EOT

open(CHANGES,"<Changes") or die;
<CHANGES>;                      # Skip version on first line
while (<CHANGES>) {
    last if /^\*/;
    print unexpand(' 'x6 . expand($_));
}
close CHANGES;

print <<'EOT';
LICENSE
	LibA2 is free software; you can redistribute it and/or modify
	it under the same terms as Perl itself.

	LibA2 is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
	either the GNU General Public License or the Artistic License
	for more details.

BUGS
    If you use Unix or a similar operating system
	The utilities don't have the executable attribute set.  Sorry,
	but I use OS/2 and can't figure out how to create tar archives
	with the executable bit set.  Please change into the `bin'
	directory and type `chmod a+x *.pl'.  If you know of a better
	way of fixing this, please let me know.

    Documentation
	There isn't enough.  Yet.  If you'd like to read it, send
	email.  If I think people want to read it, I'm far more likely
	to write it. :-)  Until then, use the source, Luke.

    prodos.pl
	There's no way to copy a file from a disk image under another
	name.  This may cause problems under MS-DOS when extracting
	files that don't meet its 8.3 filename limitations.
	Solution: Upgrade to OS/2 and use HPFS. :-)

    pro_fmt.pl
	The disk images it creates aren't bootable unless you copy the
	boot blocks from a bootable disk.

AUTHOR
	Christopher J. Madsen <cjm@pobox.com>
EOT
#'

exit;

#=====================================================================
# Subroutines:
#---------------------------------------------------------------------
# Print a module name and current version number:

sub list_mod
{
    my $file = $_[0];
    my $version;
    open(PL,"<lib/$file") or die "Can't open lib/$file";
    while (<PL>) {
        $version = $1, last if /^\# Version: ([0-9.]+)/;
    }
    close PL;
    die "No version for $file" unless $version;
    $file =~ s!/!::!g;
    $file =~ s/\.pm$//;
    print "\n    $file\tversion $version\n";
} # end list_mod

#---------------------------------------------------------------------
# Print a script name and current version number:

sub list_util
{
    my $file = $_[0];
    my $version;
    open(PL,"<bin/$file") or die "Can't open bin/$file";
    while (<PL>) {
        $version = $1, last if /^\# $file ([0-9.]+)/i;
    }
    close PL;
    die "No version for $file" unless $version;
    $file .= "\t" unless length($file) > 11;
    print "\n    $file\tversion $version\n";
} # end list_util

# Local Variables:
#   tmtrack-file-task: "LibA2: README"
# End:
