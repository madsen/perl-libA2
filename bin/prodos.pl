#!perl
#---------------------------------------------------------------------
# $Id: prodos.pl,v 0.5 1996/08/03 17:09:47 Madsen Exp $
# Copyright 1996 Christopher J. Madsen
#
# A command-line shell for accessing ProDOS disk images
#---------------------------------------------------------------------

use AppleII::ProDOS qw(0.014 shell_wc);
use Term::ReadLine;

my $term = Term::ReadLine->new('ProDOS Shell');

if ($term->ReadLine eq 'Term::ReadLine::readline_pl') {
    $readline::rl_basic_word_break_characters     = ". \t\n";
    $readline::rl_completer_word_break_characters =
    $readline::rl_completer_word_break_characters = " \t\n";
    $readline::rl_completion_function =
    $readline::rl_completion_function = \&completeWord;
} # end if readline.pl

my $vol  = AppleII::ProDOS->open($ARGV[0],'w');

print $vol->directory,"\n";

while (1) {
    $_ = $term->readline(']');
    next unless /\S/;
    $term->addhistory($_);

    my ($cmd, $arg) = /^\s*(\S+)\s*(.+?)?\s*$/;
    $cmd = lc $cmd;
    $arg = $arg || '';
    last if $cmd =~ /^q(?:uit)?$/;
    eval {
      CMD: {
        print($vol->directory,"\n"),        next CMD if $cmd eq 'pwd';
        print($vol->directory($arg),"\n"),  next CMD if $cmd eq 'cd';
        print($vol->catalog,"\n"),          next CMD if $cmd eq 'cat';
        print($vol->getFile($arg)->asText), next CMD if $cmd eq 'type';
        getFile($vol,$arg),                 next CMD if $cmd eq 'get';
        putFile($vol,$arg),                 next CMD if $cmd eq 'put';
        system('/bin/sh'),                  next CMD if $cmd eq '!';
        system(substr("$cmd $arg",1)),      next CMD if $cmd =~ /^!/;
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
sub completeWord
{
  my ($text, $line, $start) = @_;
  return grep(/^$text/, qw(cat cd get put pwd quit type)) if $start == 0;
  return &readline::rl_filename_list   if $line =~ /^put\b/;
  return $vol->listMatches(shell_wc("$text*"),'DIR') if $line =~ /^cd\b/;
  $vol->listMatches(shell_wc("$text*"),'!DIR');
} # end completeWord

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
