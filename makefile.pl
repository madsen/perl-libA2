#!perl
#---------------------------------------------------------------------
# $Id: makefile.pl,v 1.3 1997/02/25 05:51:48 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# Makefile.PL for LibA2
#---------------------------------------------------------------------

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME     => 'LibA2',
    DISTNAME => 'LibA2',
    linkext  => {LINKTYPE => ''}, # not needed for MakeMakers gt '5.00'
    VERSION  => '0.003',
    EXE_FILES => [ glob 'bin/*.pl' ],
    dist     => {COMPRESS => 'gzip -9f', SUFFIX => 'gz',
# This next line is just for my own use, you can comment it out if you want:
                 TO_UNIX => 'cjm_fixup $(DISTVNAME)' # Converts CRLF to LF
                },
);

# Local Variables:
#   tmtrack-file-task: "LibA2: Makefile.PL"
# End:
