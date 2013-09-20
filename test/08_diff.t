#!/usr/bin/perl -w

use strict;
use POSIX qw(strftime);
#use Test::More qw(no_plan); # tests => 12;
use Test::More tests => 34;
use test_util qw(write_to_file);

my $TMPDIR = $test_util::TEST_TMPDIR;

# time depends on timezone, so set TZ here
$ENV{TZ} = 'UTC';
my $zerotime = '1970-01-01 00:00:00.000000000 +0000';

sub unified_fakediff ($$$$$) {
    my ($type, $file1, $file2, $val1, $val2) = @_;
    my $expected =<<EOF;
--- $file1#~~$type\t$zerotime
+++ $file2#~~$type\t$zerotime
@@ -1 +1 @@
-$val1
+$val2
EOF
    return $expected;
}

sub simple_fakediff ($$$$$) {
    my ($type, $file1, $file2, $val1, $val2) = @_;
    my $expected =<<EOF;
diff $file1#~~$type $file2#~~$type
1c1
< $val1
---
> $val2
EOF
    # see FIXME in diff() in slack-diff
    if ($type ne 'filetype' and $type ne 'target') {
        $expected .= "diff -N $file1 $file2\n";
    }
    return $expected;
}


{
    my $output = `../src/slack-diff --version`;
    is($?, 0, 'version exit code');
    like($output, qr/^slack-diff version [\d\.]+$/, 'version')
}

{
    my $file1 = "$TMPDIR/file1";
    my $file2 = "$TMPDIR/file2";
    my $text1 = "foo\n";
    # this depends on the config inside slack-diff
    my $diff_cmd_expected = "diff -N";
    my ($output, $expected);

    unlink $file1, $file2;
    write_to_file($file1, $text1);
    write_to_file($file2, $text1);
    # see FIXME in diff() in slack-diff
    $expected = "$diff_cmd_expected $file1 $file2\n";
    $output = `../src/slack-diff $file1 $file2`;
    is($?, 0, 'simple no diff exit code');
    is($output, $expected, 'simple no diff');

    $expected = '';
    $output = `../src/slack-diff -u $file1 $file2`;
    is($?, 0, 'unified no diff exit code');
    is($output, $expected, 'unified no diff');

    my $text2 = "bar\n";
    write_to_file($file2, $text2);

    $output = `../src/slack-diff $file1 $file2`;
    is($?, 1 << 8, 'simple diff exit code');
    $expected = "$diff_cmd_expected $file1 $file2\n" .
                "1c1\n< $text1---\n> $text2";
    is($output, $expected, 'simple diff');

    my @output = `../src/slack-diff -u $file1 $file2`;
    is($?, 1 << 8, 'unified diff exit code');
    # strip the times so we're not testing diff's time formatting :)
    $output[0] =~ s/\t.*//;
    $output[1] =~ s/\t.*//;
    $expected =<<EOF;
--- $file1
+++ $file2
@@ -1 +1 @@
EOF
    $expected .= "-$text1+$text2";
    is(join('',@output), $expected, 'unified diff');

    unlink $file1, $file2;
}

{
    my $file1 = "$TMPDIR/file1";
    my $file2 = "$TMPDIR/file2";
    my $file3 = "$TMPDIR/file3";
    my $mode1 = '0644';
    my $mode2 = '0600';
    my ($output, $expected);
    
    unlink $file1, $file2, $file3;
    write_to_file($file1, '');

    mkdir $file2
        or die;
    $expected = simple_fakediff('filetype', $file1, $file2,
                                'regular file', 'directory');
    $output = `../src/slack-diff $file1 $file2`;
    is($?, 1 << 8, 'filetype fakediff exit code');
    is($output, $expected, 'filetype fakediff');

    $expected = unified_fakediff('filetype', $file1, $file2,
                                'regular file', 'directory');
    $output = `../src/slack-diff -u $file1 $file2`;
    is($?, 1 << 8, 'filetype unified fakediff exit code');
    is($output, $expected, 'filetype unified fakediff');

    $expected = "File types differ between regular file $file1 " .
                "and directory $file2\n";
    $output = `../src/slack-diff --nofakediff $file1 $file2`;
    is($?, 1 << 8, 'filetype diff exit code');
    is($output, $expected, 'filetype diff');

    rmdir $file2
        or die;
    
    write_to_file($file2, '');

    link($file2, $file3)
        or die;

    $expected = simple_fakediff('nlink', $file1, $file2, 1, 2);
    $output = `../src/slack-diff $file1 $file2`;
    is($?, 1 << 8, 'nlink fakediff exit code');
    is($output, $expected, 'nlink fakediff');

    $expected = unified_fakediff('nlink', $file1, $file2, 1, 2);
    $output = `../src/slack-diff -u $file1 $file2`;
    is($?, 1 << 8, 'nlink unified fakediff exit code');
    is($output, $expected, 'nlink unified fakediff');

    $expected = "Link counts differ between regular files $file1 and $file2\n".
                "diff -N $file1 $file2\n";
    $output = `../src/slack-diff --nofakediff $file1 $file2`;
    is($?, 1 << 8, 'nlink diff exit code');
    is($output, $expected, 'nlink diff');

    unlink $file3
        or die;

    chmod oct($mode1), $file1
        or die;
    chmod oct($mode2), $file2
        or die;

    
    $expected = simple_fakediff('mode', $file1, $file2, $mode1, $mode2);
    $output = `../src/slack-diff $file1 $file2`;
    is($?, 1 << 8, 'mode fakediff exit code');
    is($output, $expected, 'mode fakediff');

    $expected = unified_fakediff('mode', $file1, $file2, $mode1, $mode2);
    $output = `../src/slack-diff -u $file1 $file2`;
    is($?, 1 << 8, 'mode unified fakediff exit code');
    is($output, $expected, 'mode unified fakediff');

    $expected = "Modes differ between regular files $file1 and $file2\n" .
                "diff -N $file1 $file2\n";
    $output = `../src/slack-diff --nofakediff $file1 $file2`;
    is($?, 1 << 8, 'mode diff exit code');
    is($output, $expected, 'mode diff');

    unlink $file1, $file2
        or die;

    my $target1 = '/var/tmp';
    my $target2 = '/var/pmt';
    symlink($target1, $file1)
        or die;
    symlink($target2, $file2)
        or die;

    $expected = simple_fakediff('target', $file1, $file2, $target1, $target2);
    $output = `../src/slack-diff $file1 $file2`;
    is($?, 1 << 8, 'symlink target fakediff exit code');
    is($output, $expected, 'symlink target fakediff');

    $expected = unified_fakediff('target', $file1, $file2, $target1, $target2);
    $output = `../src/slack-diff -u $file1 $file2`;
    is($?, 1 << 8, 'symlink target unified fakediff exit code');
    is($output, $expected, 'symlink target unified fakediff');

    $expected = "Symlink targets differ between $file1 and $file2\n";
    $output = `../src/slack-diff --nofakediff $file1 $file2`;
    is($?, 1 << 8, 'symlink target diff exit code');
    is($output, $expected, 'mode diff');

    unlink $file1, $file2
        or die;
}

