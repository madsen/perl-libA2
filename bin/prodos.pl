#!perl
#---------------------------------------------------------------------
# $Id: prodos.pl,v 0.2 1996/07/31 19:57:29 Madsen Exp $
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
    next unless /\S/;
    $term->addhistory($_);

    my ($cmd, $arg) = /^\s*(\S+)\s*(.+)?/;
    $cmd = lc $cmd;
    last if $cmd =~ /^q(?:uit)?$/;
    eval {
      CMD: {
        print($vol->directory,"\n"),      next CMD if $cmd eq 'pwd';
        print($vol->directory($arg),"\n"),next CMD if $cmd eq 'cd';
        print($vol->catalog,"\n"),        next CMD if $cmd eq 'cat';
        print "Bad command `$cmd'\a\n";
      } # end CMD
    };
    if ($@) {
        $@ =~ /^(.+) at \Q$0\E line \d+$/ or die $@;
        print $1,"\a\n";
    }
} # end forever
