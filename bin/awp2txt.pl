#!perl
#---------------------------------------------------------------------
# $Id: awp2txt.pl,v 0.1 1996/08/11 23:03:48 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# Convert AppleWorks word processor files to text
#---------------------------------------------------------------------

my $filename = $ARGV[0];

die unless -f $filename;

open(IN,"<$filename") or die;
binmode IN;

my $header = '';
read(IN,$header,300) == 300 or die;

if (substr($header,183,1) ne "\0") {
    print STDERR "AppleWorks 3.0 or later\n";
    my $skip = '';
    read(IN,$skip,2);
}

while (1) {
    my $record = '';
    read(IN,$record,2) == 2 or die;
    my ($byte0, $byte1) = unpack('C2',$record);
    if ($byte1 == 0xD0) {
        print "\n";             # CR record
    } elsif ($byte1 > 0xD0) {
        last if $record eq "\xFF\xFF";
        next;                   # Command record
    } elsif ($byte1 == 0) {
        # Text record
        my ($data,$byte2,$byte3) = '';
        read(IN,$data,$byte1*0x100 + $byte0) or die;
        ($byte2,$byte3,$data) = unpack('C2A*',$data);
        next if $byte2 == 0xFF; # Tab ruler
        print ' ' x ($byte2 & 0x7F);
        $data =~ tr/\x01-\x1F//d; # FIXME handle special codes
        print $data,"\n";
    } else {
        die sprintf("Unknown record type %02X%02X", $byte1, $byte0);
    }
} # end forever
