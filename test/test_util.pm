package test_util ;
use strict;
use warnings;

use Cwd;
use Sys::Hostname;

{
    require Exporter;
    use vars qw(@ISA @EXPORT @EXPORT_OK);
    
    @ISA = qw(Exporter);
    @EXPORT = ();
    @EXPORT_OK = qw(gen_config_file gen_wanted write_to_file);
}
use vars qw($test_config_file %test_config @test_roles $test_hostname);
use vars qw($TEST_TMPDIR);
push @EXPORT, qw($test_config_file %test_config @test_roles $test_hostname);

# Because all the scripts chdir('/'), we need to know the cwd for our configs
my $TEST_DIR = getcwd;
$TEST_TMPDIR = $ENV{TEST_TMPDIR};
$test_hostname = hostname;
 
$test_config_file = "$TEST_TMPDIR/slack.conf";
%test_config = (
    'source' => "$TEST_DIR/testsource",
    'role-list' => "$TEST_TMPDIR/roles.conf",
    'cache' => "$TEST_TMPDIR/cache",
    'stage' => "$TEST_TMPDIR/stage",
    'root' => "$TEST_TMPDIR/root",
    'backup-dir' => "$TEST_TMPDIR/backups",
    'verbose' => 0,
);

@test_roles = sort qw(role1 role2.sub role3.sub.sub);

sub gen_config_file ($$) {
    my ($template_file, $file) = @_;

    open(TEMPLATE, "<", "$template_file")
        or die "Could not open template file $template_file: $!";
    open(FILE, ">", $file)
        or die "Could not open output file $file: $!";

    while(<TEMPLATE>) {
        s/__TEST_DIR__/$TEST_DIR/g;
        s/__TEST_TMPDIR__/$TEST_TMPDIR/g;
        s/__HOSTNAME__/$test_hostname/g;
        s/__ROLES__/join(" ", @test_roles)/ge;
        print FILE;
    }
    close(TEMPLATE)
        or die "Could not close template file $template_file: $!";
    close(FILE)
        or die "Could not close output file $file: $!";
}

# Transform globs into regexes, since I can't find a function to check
# glob matches on strings.
sub glob_to_regex ($) {
    my ($pat) = @_;
    $pat =~ s#/$##;                # strip trailing slashes
    $pat =~ s#([./^\$()+])#\\$1#g; # escape re metachars
    $pat =~ s#([?*])#.$1#g;        # convert glob metachars
    return qr(\A$pat\z);
}

# This is to help with comparing lists of files in two directory trees.
#
# Returns a wanted function for File::Find which will maintain a file list
# in a hash that looks like:
#       filename => filetype
# where valid filetypes are:
#       d       directory
#       f       regular file
#       x       executable file
#       -       unknown
# and which will skip files rsync is known to skip.
# Symlinks are dereferenced because that's what we tell rsync to do, too.
#
# Takes as arguments a basename which will be stripped off file names
# and a hash reference (in which to maintain the file list above)
sub gen_wanted ($$) {
    my ($base, $hashref) = @_;

    my @cvs_exclude;
    {
        # Suppress spurious warning about the # and , characters below
        no warnings;
        # Straight out of the rsync manpage section for --cvs-exclude
        @cvs_exclude = qw(
          RCS  SCCS  CVS  CVS.adm  RCSLOG  cvslog.*  tags TAGS .make.state
          .nse_depinfo *~ #* .#* ,* _$* *$ *.old *.bak *.BAK *.orig  *.rej
          .del-* *.a *.olb *.o *.obj *.so *.exe *.Z *.elc *.ln core .svn/
        );
    }
    @cvs_exclude = map {glob_to_regex($_)} @cvs_exclude;

    return sub {
        # Prune out files in the CVS exclude list used by rsync
        for my $pat (@cvs_exclude) {
            if (m/$pat/) {
                $File::Find::prune = 1;
                return;
            }
        }
        my $filetype = '-';
        if (-f) {
            if (-x _) {
                $filetype = 'x';
            } else {
                $filetype = 'f';
            }
        } elsif (-d _) {
            $filetype = 'd';
        }

        my $filename = $File::Find::name;
        # Try to strip off the base
        return unless ($filename =~ s#^$base/##); 
        $hashref->{$filename} = $filetype;
    };
}

sub write_to_file ($$) {
    my ($file, $text) = @_;
    my $fh;
    open($fh, '>', $file)
        or die "Could not open $file for writing: $!";
    print $fh $text
        or die "Could not write to $file: $!";
    close($fh)
        or die "Could not close $file: $!";
}

1;
