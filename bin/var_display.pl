#!perl
#---------------------------------------------------------------------
# $Id: var_display.pl,v 1.4 1997/02/26 02:31:29 Madsen Exp $
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
# Display the contents of an Apple II Applesoft BASIC VAR file
#
# See January 1986 Nibble (Vol 7/No 1), p.76 for more about VAR files
#---------------------------------------------------------------------

*ARG = *_;
use strict;
use vars qw(*ARG);

open(IN,"<$ARGV[0]") or die "Unable to open `$ARGV[0]'";
binmode IN;

my $header = '';
read(IN,$header,5) == 5 or die "Short file";

my ($varSize,$simpleSize,$himem) = unpack('SSC',$header);

my ($simple,$arrays,$strings) = ('','','');
read(IN,$simple,$simpleSize);
read(IN,$arrays,$varSize-$simpleSize);
read(IN,$strings,0xFFFF);       # Read the string variables

close IN;

my $offset = $himem * 0x100 - length($strings);

while ($ARG = substr($simple,0,7)) {
    substr($simple,0,7) = '';
    my ($name, $type) = parseName($ARG);
    printf("%s\$ = %s\n", $name, getQuotedString(substr($ARG,2)))
        if $type eq '01';
}

while ($arrays) {
    my ($name, $length, $order) = unpack('a2SC',$arrays);
    my $array = substr($arrays,5,$length-5);
    substr($arrays,0,$length) = '';

    my $type;
    ($name, $type) = parseName($name);

    if ($type eq '01' and $order == 1) {
        my @size = unpack("n$order", $array);
        substr($array,0,2*$order) = '';

        my $i;
        for ($i = 0; $i < $size[0]; ++$i) {
            printf("%s\$(%d) = %s\n", $name, $i, getQuotedString($array));
            substr($array,0,3) = '';
        }
    }
}

exit;

#=====================================================================
# Subroutines:
#---------------------------------------------------------------------
# Return a string value:
#
# Input:
#   The string information

sub getString
{
    my ($length, $address) = unpack('CS',$ARG[0]);
    if ($length) { substr($strings,$address-$offset,$length) }
    else         { ''                                        }
} # end getString

#---------------------------------------------------------------------
# Return a string value with quotes around it:
#
# Quotes backslashes, quotes, and control characters.
#
# Input:
#   Same as getString

sub getQuotedString
{
    my $string = &getString;
    $string =~ s!([\"\\])!\\$1!g; # Quote quotes & backslashes
    $string =~ s!\r!\\n!g;        # Change C-m to \n
    $string =~ s!([\x00-\x1F])!sprintf('\x%02x',ord($1))!eg;
    '"' . $string . '"';
} # end getQuotedString

#---------------------------------------------------------------------
# Parse a name to determine its type:
#
# Input:
#   The encoded name to parse (2 bytes)
#
# Returns:
#   A list ($name, $type), where TYPE is:
#     00  Floating point
#     11  Integer
#     01  String
#     10  Function

sub parseName
{
    my $name = substr($ARG[0],0,2);
    my $type = $name;

    $type =~ tr[\x00-\x7F][0];
    $type =~ tr[\x80-\xFF][1];

    $name =~ tr[\x80-\xFF][\x00-\x7F]; # Strip high bit
    $name =~ tr/\000//d;               # Delete nulls

    ($name, $type);
} # end parseName

__END__

=head1 NAME

var_display - Display the strings stored in an Applesoft BASIC VAR file

=head1 SYNOPSIS

B<var_display> VAR-FILE

=head1 DESCRIPTION

B<var_display> lists the contents of an Applesoft BASIC VAR file.
Currently, it can only display string variables and string arrays.
The strings are formatted ready to drop into a C or Perl program, with
Control-M (the Apple's end-of-line character) displayed as C<\n>,
backslashes and quotation marks quoted (C<\\> and C<\">), and control
characters in the range \x00 to \x1F displayed in hexadecimal
notation.

=head1 REQUIREMENTS

B<var_display> is a stand-alone utility.

=head1 BUGS

B<var_display> only displays string variables and one-dimensional
string arrays.  It wouldn't be hard to add support for integer and
floating-point variables or multi-dimensional arrays, but I don't need
it.  If you do, send email!

=head1 AUTHOR

Christopher J. Madsen E<lt>F<ac608@yfn.ysu.edu>E<gt>

=cut

# Local Variables:
# tmtrack-file-task: "LibA2: var_display.pl"
# End:
