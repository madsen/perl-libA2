#!perl
#---------------------------------------------------------------------
# $Id: prodos.pl,v 0.8 1996/08/12 21:14:48 Madsen Exp $
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
# A command-line shell for accessing ProDOS disk images
#---------------------------------------------------------------------

use AppleII::ProDOS qw(0.016 shell_wc);
use Term::ReadLine;

my @commands = qw(cd get lcd ls ll mkdir put pwd quit type);

my $term = Term::ReadLine->new('ProDOS Shell');

if ($term->ReadLine eq 'Term::ReadLine::readline_pl') {
    $readline::rl_basic_word_break_characters     = ". \t\n";
    $readline::rl_completer_word_break_characters =
    $readline::rl_completer_word_break_characters = " \t\n";
    $readline::rl_completion_function =
    $readline::rl_completion_function = \&complete_word;
} # end if readline.pl

my $vol  = AppleII::ProDOS->open($ARGV[0],'w');

print $vol->path,"\n";

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
        print($vol->path,"\n"),              next CMD if $cmd eq 'pwd';
        print($vol->path($arg),"\n"),        next CMD if $cmd eq 'cd';
        print($vol->catalog,"\n"),           next CMD if $cmd =~ /^l[sl]$/;
        print($vol->get_file($arg)->as_text),next CMD if $cmd eq 'type';
        get_file($vol,$arg),                 next CMD if $cmd eq 'get';
        put_file($vol,$arg),                 next CMD if $cmd eq 'put';
        $vol->new_dir($arg),                 next CMD if $cmd eq 'mkdir';
        (chdir($arg) || die "Bad directory"),next CMD if $cmd eq 'lcd';
        system('/bin/sh'),                   next CMD if $cmd eq '!';
        system(substr("$cmd $arg",1)),       next CMD if $cmd =~ /^!/;
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
sub complete_word
{
  my ($text, $line, $start) = @_;
  return grep(/^$text/, @commands)     if $start == 0;
  return &readline::rl_filename_list   if $line =~ /^(?:put|lcd)\b/;
  return $vol->dir->list_matches(shell_wc("$text*"),'DIR') if $line =~ /^cd\b/;
  $vol->dir->list_matches(shell_wc("$text*"),'!DIR');
} # end complete_word

#---------------------------------------------------------------------
sub get_file
{
    my ($vol, $arg) = @_;

    die "$arg already exists" if -e $arg;

    my $file = $vol->get_file($arg);

    open(OUT, ">$arg") or die;
    binmode OUT;
    print OUT $file->data;
    close OUT;
} # end get_file

#---------------------------------------------------------------------
sub put_file
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

    $vol->put_file($file);
} # end put_file
