#!perl
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
# Create a blank ProDOS disk image
#---------------------------------------------------------------------

use AppleII::ProDOS 0.016;

my $vol = AppleII::ProDOS->new(@ARGV);
