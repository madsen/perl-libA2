#! /usr/bin/perl
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
# Convert AppleWorks word processor files to text files
#---------------------------------------------------------------------

foreach $filename (@ARGV) {
    die "$filename: not a normal file" unless -f $filename;
    if (-e "$filename.txt") {
        print STDERR "$filename.txt already exists, skipping it...\n";
        next;
    }

    open(IN,"<$filename") or die "Can't open `$filename'";
    binmode IN;

    my $header = '';
    read(IN,$header,300) == 300 or die "$filename: unexpected end-of-file";

    if (substr($header,4,1) ne "\x4F") {
        print STDERR "$filename is not an AppleWorks word processor file\n";
        next;
    }

    open(OUT,">$filename.txt") or die "Can't write `$filename.txt'";

    print STDERR "Converting $filename to $filename.txt...\n";

    if (substr($header,183,1) ne "\0") {
        #print STDERR "AppleWorks 3.0 or later\n";
        seek(IN,2,1);           # Skip over invalid line record (two bytes)
    }

    my $line = 0;

    while (1) {
        my $record = '';
        read(IN,$record,2) == 2 or die "$filename: unexpected end-of-file";
        my ($byte0, $byte1) = unpack('C2',$record);
        if ($byte1 == 0xD0) {
            ++$line;
            print OUT "\n";     # CR record
        } elsif ($byte1 > 0xD0) {
            last if $record eq "\xFF\xFF";
            next;               # Command record
        } elsif ($byte1 == 0) {
            # Text record
            ++$line;
            my ($data,$byte2,$byte3) = '';
            read(IN,$data,$byte1*0x100 + $byte0) or die"$filename: read error";
            ($byte2,$byte3,$data) = unpack('C2A*',$data);
            next if $byte2 == 0xFF; # Tab ruler
            # Untabify & delete special codes:
            $data =~ tr/\x16\x17\x01-\x1F/  /d;
            print OUT ' ' x ($byte2 & 0x7F), $data, "\n";
        } else {
            die sprintf("%s: unknown record type %02X%02X after line %d",
                        $filename, $byte0, $byte1, $line);
        }
    } # end forever

    close IN;
    close OUT;
} # end foreach $filename

__END__

=head1 NAME

awp2txt - Convert AppleWorks word processor files to text files

=head1 SYNOPSIS

B<awp2txt> FILE [FILE ...]

=head1 DESCRIPTION

B<awp2txt> converts AppleWorks word processor files to plain text
file.  For each FILE specified on the command line, it writes the
contents to FILE.txt.  The original files are not changed.  If
FILE.txt already exists, it is I<not> overwritten.

=head1 REQUIREMENTS

B<awp2txt> is a stand-alone utility.

=head1 BUGS

There are no known bugs.

=head1 AUTHOR

Christopher J. Madsen E<lt>F<cjm@pobox.com>E<gt>

=cut

# Local Variables:
# tmtrack-file-task: "LibA2: awp2txt.pl"
# End:
