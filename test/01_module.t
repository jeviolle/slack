#!/usr/bin/perl -w

use strict;
use Test::More tests => 40;

BEGIN {
    chdir 'test' if -d 'test';
    unshift @INC, '../src';
    use_ok("Slack");
}

use test_util;

# Make sure all the expected funtions are there
can_ok("Slack", qw(default_usage read_config get_system_exit check_system_exit get_options prompt find_files_to_install wrap_rsync wrap_rsync_fh));

# default_usage()
{
    my $usage = Slack::default_usage("qwxle");
    like($usage, qr/\AUsage: qwxle\n/, "Usage statement");
}


# read_config()
{
    my $opt = Slack::read_config(
        file => $test_config_file,
    );

    is_deeply(\%test_config, $opt, "read_config keys");
}

# get_system_exit()
{
    # clear variables
    $! = 0;
    $? = 0;

    system('true');
    eval "Slack::get_system_exit('');";
    like($@, qr#Unknown error#, "get_system_exit exit true");

    system('false');
    my $ret = Slack::get_system_exit('');
    is($ret, 1);

    system('kill -KILL $$');
    eval "Slack::get_system_exit('');";
    like($@, qr#'' caught sig 9\b#, "get_system_exit signal");
}

# check_system_exit
{
    $! = 0;
    $? = 0;

    system('false');
    eval "Slack::check_system_exit('');";
    like($@, qr#'' exited 1\b#, "check_system_exit exit false");
}

# get_options()
{
    my $e = 1; # a counter -- we check for exceptions a lot
    my $opt; # a place to store the options hashref
    my $cl_opt; # likewise for command like hash
    # We require hostname to be set, as get_options does
    # (I suppose we could skip this whole section if we can't get hostname,
    #  since get_options will just throw an exception)
    require Sys::Hostname;
    my $hostname = Sys::Hostname::hostname;

    # First, we check the setting of options and defaults in the absence
    # of a config file.
    eval {
        local @ARGV = (
            '--config=/dev/null',
            "--source=/foo/bar.$$",
        );
        $opt = Slack::get_options();
    };
    is($@, '', "get_options exception ".$e++);
    is($opt->{verbose}, 0, "get_options default verbosity");
    is($opt->{source}, "/foo/bar.$$", "get_options command line source");
    is($opt->{hostname}, $hostname, "get_options hostname");

    eval {
        local @ARGV = (
            '--config=/dev/null',
            '-vv',
        );
        $opt = Slack::get_options();
    };
    is($@, '', "get_options exception ".$e++);
    is($opt->{verbose}, 2, "get_options verbosity increments");

    eval {
        local @ARGV = (
            '--config=/dev/null',
            '-vv', '--quiet', '-v',
        );
        $opt = Slack::get_options();
    };
    is($@, '', "get_options exception ".$e++);
    is($opt->{verbose}, 1, "get_options --quiet");

    # Make sure it works if you pass in $opt, instead of getting return
    eval {
        $opt = {};
        local @ARGV = (
            '--config=/dev/null',
            '-vv',
        );
        Slack::get_options(
            opthash => $opt,
        );
    };
    is($@, '', "get_options exception ".$e++);
    is($opt->{verbose}, 2, "get_options pass in opthash");

    # Next, we check config file parsing.
    eval {
        local @ARGV = (
            "--config=$test_config_file",
        );
        $opt = Slack::get_options();
    };
    is($@, '', "get_options exception ".$e++);
    # A few extra things should be set
    local $test_config{config} = $test_config_file;
    local $test_config{hostname} = $hostname;

    is_deeply($opt, \%test_config, "get_options config keys");

    eval {
        $cl_opt = {};
        local @ARGV = (
            "--config=$test_config_file",
            "--source=/foo/bar.$$",
        );
        $opt = Slack::get_options(
            command_line_hash => $cl_opt,
        );
    };
    is($@, '', "get_options exception ".$e++);
    is($opt->{source}, "/foo/bar.$$",
        "get_options command line overrides config file");
    is($cl_opt->{source}, $opt->{source},
        "get_options command_line_hash source set");
    is($cl_opt->{config}, $test_config_file,
        "get_options command_line_hash config set");
    is(scalar keys %{$cl_opt}, 2,
        "get_options command_line_hash not over-set");

    # Next, non-standard option parsing
    eval {
        local @ARGV = (
            '--config=/dev/null',
            "--foo=$$",
            "--bar=a.$$",
            '--baz',
        );
        $opt = Slack::get_options(
            command_line_options => [
                'foo=i',
                'bar=s',
                'baz',
            ],
        );
    };
    is($@, '', "get_options exception ".$e++);
    is($opt->{foo}, $$, "get_options extra options (int)");
    is($opt->{bar}, "a.$$", "get_options extra options (string)");
    ok($opt->{baz}, "get_options extra options (boolean)");

    # Next, required options
    #   first, when everything should be OK
    eval {
        local @ARGV = (
            "--config=$test_config_file",
            "--foo=$$",
        );
        $opt = Slack::get_options(
            command_line_options => [
                'foo=i',
            ],
            required_options => [qw(foo source)],
        );
    };
    is($@, '', "get_options exception ".$e++);

    #   second, when we should throw an exception because a
    #      required option is missing.
    eval {
        local @ARGV = (
            '--config=/dev/null',
            "--foo=$$",
        );
        $opt = Slack::get_options(
            command_line_options => [
                'foo=i',
            ],
            required_options => [qw(foo source)],
        );
    };
    like($@, qr/Required option/, "get_options required options");

    # test --help with:
    {
        my $helptext = `perl -I$INC[0] -MSlack -e 'Slack::get_options' -- --help`;
        is($?, 0, "get_options --help exit code");
        like($helptext, qr/^Usage: /m, "get_options --help output");
    }

    # test --usage with:
    {
        my $helptext = `perl -I$INC[0] -MSlack -e 'Slack::get_options' -- --invalid 2>&1`;
        isnt($?, 0, "get_options usage exit code");
        like($helptext, qr/^Usage: /m, "get_options usage output");
    }

    # test --version with
    {
        my $versiontext = `perl -I$INC[0] -MSlack -e 'Slack::get_options' -- --version`;
        is($?, 0, 'get_options --version exit code');
        like($versiontext, qr/^slack version [\d\.]+$/, 'get_options --version output')
    }
}
 

# prompt
# difficult to test

# find_files_to_install
# Some of the later functional tests will test this.

# wrap_rsync
{
    eval "Slack::wrap_rsync('true');";
    is($@, '', 'wrap_rsync no exception');

    eval "Slack::wrap_rsync('false');";
    like($@, qr#'false' exited 1\b#, 'wrap_rsync exit false');
}

# wrap_rsync_fh
{
    my $tmpfile = $test_util::TEST_TMPDIR . '/output';
    my $test_text = "test\n";

    my @command = ('/bin/sh', '-c', "cat > $tmpfile");
    my ($fh) = Slack::wrap_rsync_fh(@command);
    print $fh $test_text, "\n";
    close($fh)
        or die "'@command' failed!";

    open($fh, '<', $tmpfile)
        or die "could not open $tmpfile";
    my $line = <$fh>;
    close($fh)
        or die "could not close $tmpfile";

    is($line, $test_text, 'wrap_rsync_fh cat test');
    unlink($tmpfile)
        or die "could not unlink $tmpfile";
}
