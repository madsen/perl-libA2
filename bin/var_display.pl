#!perl
#---------------------------------------------------------------------
# $Id: var_display.pl,v 1.1 1996/04/12 16:07:26 Madsen Exp $
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
printf "%x %x %x\n",$varSize,$simpleSize,$himem;

my ($simple,$arrays,$strings) = ('','','');
read(IN,$simple,$simpleSize);
read(IN,$arrays,$varSize-$simpleSize);
read(IN,$strings,0xFFFF);       # Read the string variables

close IN;

my $offset = $himem - length($strings);

printf "%x\n",$offset;

while ($ARG = substr($simple,0,7)) {
    substr($simple,0,7) = '';
    if (/^[\x00-\x7F][\x80-\xFF]/) {
        my ($name, $length, $address) = unpack('a2CS',$ARG);
        $name =~ tr[\x80-\xFF][\x00-\x7F]; # Strip high bit
        $name =~ tr/\000//d;               # Delete nulls
        printf("$name\$ = \"%s\"\n",
               substr($strings,$address-$offset,$length));
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
                my ($length, $address) = unpack('CS',$arrays);
                substr($arrays,0,3) = '';
                printf("$name\$($i) = \"%s\"\n",
                       substr($strings,$address-$offset,$length));
            }
        }
    }
}
