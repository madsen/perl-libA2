#!perl
#---------------------------------------------------------------------
# $Id: var_display.pl,v 1.2 1996/04/12 16:31:00 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# Display the contents of an Apple II Applesoft BASIC VAR file
#---------------------------------------------------------------------

use English;

open(IN,"<$ARGV[0]") or die;
binmode IN;

my $header = '';
read(IN,$header,5) == 5 or die;

my ($varSize,$simpleSize,$himem) = unpack('SSC',$header);

$himem *= 0x100;

my ($simple,$arrays,$strings) = ('','','');
read(IN,$simple,$simpleSize);
read(IN,$arrays,$varSize-$simpleSize);
read(IN,$strings,0xFFFF);       # Read the string variables

close IN;

my $offset = $himem - length($strings);

while ($ARG = substr($simple,0,7)) {
    substr($simple,0,7) = '';
    if (/^([\x00-\x7F][\x80-\xFF])/) {
        my $name = $1;
        $name =~ tr[\x80-\xFF][\x00-\x7F]; # Strip high bit
        $name =~ tr/\000//d;               # Delete nulls
        printf("$name\$ = %s\n", getQuotedString(substr($ARG,2)));
    }
}

while ($ARG = substr($arrays,0,5)) {
    substr($arrays,0,5) = '';
    if (/^[\x00-\x7F][\x80-\xFF]/) {
        my ($name, $length, $order) = unpack('a2SC',$ARG);
        my @size = unpack("n$order", $arrays);
        substr($arrays,0,2*$order) = '';
        $name =~ tr[\x80-\xFF][\x00-\x7F]; # Strip high bit
        $name =~ tr/\000//d;               # Delete nulls
        if ($order == 1) {
            my $i;
            for ($i = 0; $i < $size[0]; ++$i) {
                printf("$name\$($i) = %s\n", getQuotedString($arrays));
                substr($arrays,0,3) = '';
            }
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
# Input:
#   Same as getString

sub getQuotedString
{
    my $string = &getString;
    $string =~ s!([\"\\])!\\$1!g; # Quote quotes & backslashes
    $string =~ s!\r!\\n!g;        # Change C-m to \n
    $string =~ s!([\x00-\x1F])!sprintf('\x%02x',ord($1))!eg;
    '"' . $string . '"';
}
