#!perl
#---------------------------------------------------------------------
# $Id: awp2txt.pl,v 0.2 1996/08/11 23:28:03 Madsen Exp $
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
#    print STDERR "AppleWorks 3.0 or later\n";
    seek(IN,2,1);               # Skip over invalid line record (two bytes)
}

my $line = 0;

while (1) {
    my $record = '';
    read(IN,$record,2) == 2 or die;
    my ($byte0, $byte1) = unpack('C2',$record);
    if ($byte1 == 0xD0) {
        ++$line;
        print "\n";             # CR record
    } elsif ($byte1 > 0xD0) {
        last if $record eq "\xFF\xFF";
        next;                   # Command record
    } elsif ($byte1 == 0) {
        # Text record
        ++$line;
        my ($data,$byte2,$byte3) = '';
        read(IN,$data,$byte1*0x100 + $byte0) or die;
        ($byte2,$byte3,$data) = unpack('C2A*',$data);
        next if $byte2 == 0xFF; # Tab ruler
        $data =~ tr/\x16\x17\x01-\x1F/  /d; # Untabify & delete special codes
        print ' ' x ($byte2 & 0x7F), $data, "\n";
    } else {
        die sprintf("Unknown record type %02X%02X after line %d",
                    $byte0, $byte1, $line);
    }
} # end forever
