#! /usr/bin/perl
#---------------------------------------------------------------------
# $Id: prodos.pl,v 0.11 2005/01/15 05:06:08 Madsen Exp $
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

my $maxscreen = 20;
my $pager     = $ENV{PAGER};
my $shell     = $ENV{SHELL} || '/bin/sh';

#---------------------------------------------------------------------
my @commands = qw(cd dir get lcd ls ll mkdir put pwd quit type);

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
        print("Use `dir' or `type' instead\a\n"),next CMD if $cmd eq 'cat';
        print($vol->path($arg),"\n"),        next CMD if $cmd eq 'cd';
        display($vol->catalog,"\n"),         next CMD if $cmd =~ /^l[sl]$/
            or                                           $cmd eq 'dir';
        display($vol->get_file($arg)->as_text),next CMD if $cmd eq 'type';
        get_file($vol,$arg),                 next CMD if $cmd eq 'get';
        put_file($vol,$arg),                 next CMD if $cmd eq 'put';
        $vol->new_dir($arg),                 next CMD if $cmd eq 'mkdir';
        (chdir($arg) || print "Bad directory `$arg'\a\n"),
                                             next CMD if $cmd eq 'lcd';
        system($shell),                      next CMD if $cmd eq '!';
        system(substr("$cmd $arg",1)),       next CMD if $cmd =~ /^!/;
        print "Bad command `$cmd'\a\n";
      } # end CMD
    }; # end eval
    if ($@) {
        $@ =~ /^LibA2: (.+) at \S+ line / or die $@;
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
sub display
{
    my $text = (scalar(@_) > 1 ? join('',@_) : $_[0]);
    my $lines = $text =~ tr/\n//; # Count the newlines
    if ($lines > $maxscreen and $pager) {
        open(PAGER,"|$pager") or die;
        print PAGER $text;
        close(PAGER);
    } else {
        print $text;
    }
} # end display

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

__END__

=head1 NAME

prodos - Manipulate Apple II ProDOS disk image files

=head1 SYNOPSIS

B<prodos> IMAGE-FILE

=head1 DESCRIPTION

B<prodos> provides a Unix/MS-DOS style command-line shell for
manipulating the contents of a disk image file containing an Apple II
ProDOS volume.

=head1 COMMANDS

=over 5

=item B<cd> I<PATH>

Change the current directory on the ProDOS volume to I<PATH>.  Use
B<lcd> to change the directory on the native filesystem.

=item B<dir>, B<ls>, or B<ll>

List the contents of the current directory on the ProDOS volume.

=item B<get> I<FILE>

Copy I<FILE> from the ProDOS volume to the native filesystem.

=item B<lcd> I<PATH>

Change the current directory on the native filesystem to I<PATH>.  Use
B<cd> to change the directory on the ProDOS volume.

=item B<mkdir> I<DIRECTORY>

Create a new subdirectory on the ProDOS volume.

=item B<put> I<FILE>

Copy I<FILE> from the native filesystem to the ProDOS volume.

=item B<pwd>

List the name of the current directory on the ProDOS volume.

=item B<quit>

Exit B<prodos>.

=item B<type> I<FILE>

Display the contents of I<FILE>, which should be a text file.

=item B<!>

Start a subshell.

=back

=head1 REQUIREMENTS

B<prodos> requires Term::ReadLine, available on CPAN.

It also requires the modules AppleII::ProDOS and AppleII::Disk,
which are included with LibA2.

=head1 ENVIRONMENT

 PAGER	The pager to use for long displays
 SHELL	The shell to start with the ! command

=head1 BUGS

B<prodos> doesn't have a B<cat> command, because under ProDOS that
means B<dir> and under Unix it means B<type>.  To avoid confusion, I
left it out.

=head1 AUTHOR

Christopher J. Madsen E<lt>F<cjm@pobox.com>E<gt>

=cut

# Local Variables:
#  tmtrack-file-task: "LibA2: prodos.pl"
# End:
