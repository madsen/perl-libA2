#!perl
#---------------------------------------------------------------------
# $Id: pro_fmt.pl,v 0.2 1996/08/12 17:49:47 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# Create a blank ProDOS disk image
#---------------------------------------------------------------------

use AppleII::ProDOS 0.016;

my $vol = AppleII::ProDOS->new(@ARGV);
