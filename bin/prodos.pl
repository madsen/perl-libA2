#!perl
#---------------------------------------------------------------------
# $Id: prodos.pl,v 0.1 1996/07/31 03:19:10 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# A command-line shell for accessing ProDOS disk images
#---------------------------------------------------------------------

use AppleII::ProDOS 0.006;
use Term::ReadLine;

my $term = Term::ReadLine->new('ProDOS Shell');
my $vol  = AppleII::ProDOS->new($ARGV[0]);

print $vol->directory,"\n";

while (1) {
    $_ = $term->readline(']');
    $term->addhistory($_) if /\S/;

    my ($cmd, @args) = split(' ');
    $cmd = lc $cmd;
    last if $cmd =~ /^q(?:uit)?$/;
    eval {
        print $vol->directory,"\n"        if $cmd eq 'pwd';
        print $vol->directory(@args),"\n" if $cmd eq 'cd';
        print $vol->catalog,"\n"          if $cmd eq 'cat';
    };
    if ($@) {
        $@ =~ /^(.+) at \S+ line \d+$/ or die $@;
        print $1,"\a\n";
    }
} # end forever
