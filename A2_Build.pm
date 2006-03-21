#---------------------------------------------------------------------
# $Id$
package A2_Build;
#
# Copyright 2006 Christopher J. Madsen
#
# Author: Christopher J. Madsen <cjm@pobox.com>
# Created: 13 Mar 2006
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Customize Module::Build for LibA2
#---------------------------------------------------------------------

require 5.006;
use strict;
use Cwd 'abs_path';

use base 'Module::Build';

#=====================================================================
# Package Global Variables:

our $VERSION = '0.04';

#=====================================================================

sub find_perl_interpreter
{
  my $self = shift @_;

  my $perl = $self->SUPER::find_perl_interpreter(@_);

  # Convert /usr/bin/perl5.8.6 to /usr/bin/perl:
  #  (if the latter is a symlink to the former)
  my $base = $perl;
  if ($base =~ s/[\d.]+$// and -l $base and abs_path($base) eq $perl) {
    $perl = $base;
  }

  return $perl;
} # end find_perl_interpreter

#---------------------------------------------------------------------
sub ACTION_distdir
{
  my $self = shift @_;

  my $cjm = -e 'README.PL';     # True if this is my copy

  $self->do_system($^X, 'README.PL') or die "README.PL: $!" if $cjm;

  $self->SUPER::ACTION_distdir(@_);

  $self->do_system(qw(vernum -nr), $self->dist_dir, qw(Build.PL TODO)) if $cjm;
} # end ACTION_distdir

#=====================================================================
# Package Return Value:

1;

__END__

# Local Variables:
# tmtrack-file-task: "LibA2: A2_Build.pm"
# End:
