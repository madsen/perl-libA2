#!perl
#---------------------------------------------------------------------
# $Id: var_display.pl,v 1.3 1996/11/01 00:15:00 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# Display the contents of an Apple II Applesoft BASIC VAR file
#
# See January 1986 Nibble (Vol 7/No 1), p.76 for more about VAR files
#---------------------------------------------------------------------

*ARG = *_;
use strict;
use vars qw(*ARG);

open(IN,"<$ARGV[0]") or die;
binmode IN;

my $header = '';
read(IN,$header,5) == 5 or die;

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
