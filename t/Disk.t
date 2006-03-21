# Before `./Build install' is performed this script should be runnable with
# `./Build test'. After `./Build install' it should work as `perl Disk.t'
#---------------------------------------------------------------------
# $Id$
# Copyright 2006 Christopher J. Madsen
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Test the AppleII::Disk module
#---------------------------------------------------------------------
#########################

use Test::More tests => 1;
BEGIN { use_ok('AppleII::Disk') };

#########################

# Local Variables:
# mode: perl
# End:
