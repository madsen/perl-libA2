#!perl
#---------------------------------------------------------------------
# $Id: prodos.pl,v 0.4 1996/08/02 16:22:54 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# A command-line shell for accessing ProDOS disk images
#---------------------------------------------------------------------

use AppleII::ProDOS 0.013;
use Term::ReadLine;

my $term = Term::ReadLine->new('ProDOS Shell');
my $vol  = AppleII::ProDOS->open($ARGV[0],'w');

print $vol->directory,"\n";

while (1) {
    $_ = $term->readline(']');
    next unless /\S/;
    $term->addhistory($_);

    my ($cmd, $arg) = /^\s*(\S+)\s*(.+)?/;
    $cmd = lc $cmd;
    last if $cmd =~ /^q(?:uit)?$/;
    eval {
      CMD: {
        print($vol->directory,"\n"),        next CMD if $cmd eq 'pwd';
        print($vol->directory($arg),"\n"),  next CMD if $cmd eq 'cd';
        print($vol->catalog,"\n"),          next CMD if $cmd eq 'cat';
        print($vol->getFile($arg)->asText), next CMD if $cmd eq 'type';
        getFile($vol,$arg),                 next CMD if $cmd eq 'get';
        putFile($vol,$arg),                 next CMD if $cmd eq 'put';
        print "Bad command `$cmd'\a\n";
      } # end CMD
    }; # end eval
    if ($@) {
        $@ =~ /^(.+) at \Q$0\E line \d+\.?$/ or die $@;
        print $1,"\a\n";
    }
} # end forever

exit;

#=====================================================================
# Subroutines:
#---------------------------------------------------------------------
sub getFile
{
    my ($vol, $arg) = @_;

    die "$arg already exists" if -e $arg;

    my $file = $vol->getFile($arg);

    open(OUT, ">$arg") or die;
    binmode OUT;
    print OUT $file->data;
    close OUT;
} # end getFile

#---------------------------------------------------------------------
sub putFile
{
    my ($vol, $arg) = @_;

    open(IN,"<$arg") or die;
    binmode IN;
    my $size = (stat IN)[7];
    my $data = '';
    read(IN, $data, $size) == $size or die;
    close IN;

    my $file = AppleII::ProDOS::File->new($arg, $data);
    if ($arg =~ /\.s[hd]k$/i) {
        $file->type(0xE0);
        $file->auxtype(0x8102);
    }

    $vol->putFile($file);
} # end putFile
