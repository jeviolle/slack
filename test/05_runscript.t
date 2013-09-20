#!/usr/bin/perl -w

use strict;
use Test::More tests => 18;
use test_util;

# For the scripts we will run
$ENV{PERL5LIB} = '../src';

my $role = 'runscript';

# Check various scripts
sub get_script_output (@) {
    return `../src/slack-runscript -C $test_config_file @_ 2> /dev/null`
}

sub get_script_output_hashed (@) {
    my $output = get_script_output(@_);
    my @lines = split(/\n/, $output);
    my %output;
    for my $line (@lines) {
        my ($var, $value) = split(/=/, $line, 2);
        $output{$var} = $value;
    }
    return \%output;
}

# We have to run slack-stage first so we've got as decent setup
# Be lazy and use the shell to /dev/null the warnings about not being root
(system("../src/slack-stage --config=$test_config_file --cache=$test_config{'source'} $role $role.sub 2>/dev/null") == 0)
    or die "Couldn't set up stage (needed to test runscript properly)";

# fixfiles is run in the files directory
{
    my $expected = <<EOF;
$test_config{stage}/roles/$role/files
EOF
    is(get_script_output('fixfiles', $role), $expected, "fixfiles cwd");
}

# other scripts are run in the scripts directory
{
    my $expected = <<EOF;
$test_config{stage}/roles/$role/scripts
EOF
    is(get_script_output('preinstall', $role), $expected, "other cwd");
}

# subroles are run in their own directories, not the main one
{
    my $expected = <<EOF;
$test_config{stage}/roles/$role.sub/scripts
EOF
    is(get_script_output('preinstall', "$role.sub"), $expected, "subrole cwd");
}

# These make sure we're passing the right args for roles and subroles
{
    my $expected = <<EOF;
runscript
EOF
    is(get_script_output('args', $role), $expected, "args");
}

{
    my $expected = <<EOF;
runscript.sub
EOF
    is(get_script_output('args', "$role.sub"), $expected, "subrole args");
}

# make sure we're calling all roles given
{
    my $expected = <<EOF;
runscript
runscript.sub
EOF
    is(get_script_output('args', $role, "$role.sub"), $expected, "multiple roles");
}

# exit codes done properly
{
    get_script_output('args', $role);
    is($?, 0, "propagate successes");
    get_script_output('postinstall', $role);
    isnt($?, 0, "propagate failures");
    get_script_output('no_such_script', $role);
    is($?, 0, "succeed when script missing");
}

# don't run non-executable files
{
    my $output = get_script_output('not_executable', $role);
    is($output, '', "skip when script non-executable");
    is($?, 0, "succeed when non-executable");
}

# tests our environment setup
{
    my %expected = (
        HOSTNAME => $test_hostname,
        PATH => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
        VERBOSE => 0,
        ROOT => $test_config{root},
        STAGE => $test_config{stage},
    );

    # we'll check to be sure this isn't passed along to the script
    $ENV{BADVARIABLE} = 'BAD';
    my $output = get_script_output_hashed('printenv', 'runscript');
    delete $ENV{BADVARIABLE};

    ok((not exists $output->{BADVARIABLE}), "env cleaned");

    # We explicitly don't want to export these
    ok((not exists $output->{CACHE}), "env no cache");
    ok((not exists $output->{SOURCE}), "env no source");

    # OK, now we can prune the hash of stuff we don't care about.
    #
    # The shell may have set some variables, like PWD, _, SHLVL, etc
    #   that we can't do anything about, and can't entirely predict,
    #   since it's shell-dependent, and not everyone uses bash :)
    while (my ($var, $value) = each %{$output}) {
        delete $output->{$var} if not exists $expected{$var};
    }
    is_deeply($output, \%expected, "env populated");
}

# verbosity is being propagated properly
{
    # We check three levels to make sure -v goes to zero, -vv goes
    # to non-zero (1), and -vvv goes to something more than -vv.
    # Earlier we made sure no -v doesn't go to -1.
    for my $i (1 .. 3) {
        my $output = get_script_output_hashed(
            ('-v') x $i,
            'printenv', $role,
        );
        is($output->{VERBOSE}, ($i - 1), "verbose level $i");
    }
}
