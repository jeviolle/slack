#!/usr/bin/perl -w

use strict;
use warnings FATAL => qw(all);
use Test::More;
use test_util;
import test_util qw(gen_wanted);

use File::Find;

plan tests => 15 + scalar @test_roles;

# For the scripts we will run
$ENV{PERL5LIB} = '../src';

# First, we're playing around with role1
{
    my $cache = $test_config{cache}."/roles/role1";
    my $source = $test_config{source}."/roles/role1";

    # Make sure that after sync, we have the same files in cache as in source
    {
        my $return = system("../src/slack-sync -C $test_config_file role1 2>/dev/null");
        ok(($return == 0 and $? == 0), "role1 sync return");

        ok((-d $cache), "role1 cache dir created");

        # Compare the lists of files in the two directories
        my $source_files = {};
        my $cache_files = {};
        find({wanted => gen_wanted($source, $source_files)}, $source);
        find({wanted => gen_wanted($cache, $cache_files)}, $cache);
        is_deeply($cache_files, $source_files, "role1 file list compare");
    }

    # OK, now insert a bad file into the cache
    {
        my $badfile = "$cache/files/BADFILE";
        (system("touch $badfile") == 0)
            or die "failed creating bad file for deletion test";

        my $return = system("../src/slack-sync -C $test_config_file role1 2> /dev/null");
        ok(($return == 0 and $? == 0), "file deletion sync return");

        ok((!-e $badfile), "file deletion");

        # Compare the lists of files in the two directories
        my $source_files = {};
        my $cache_files = {};
        find({wanted => gen_wanted($source, $source_files)}, $source);
        find({wanted => gen_wanted($cache, $cache_files)}, $cache);
        is_deeply($cache_files, $source_files, "file deletion file list compare");
    }

    # OK, now try out a symlink -- we expect these to be dereferenced by slack-sync
    {
        my $symlink_dir = "files/etc";
        my $symlink = "$symlink_dir/symlink";
        my $target = "role1.conf";
        my $full_target = "$symlink_dir/$target";

        unlink("$source/$symlink"); # just in case
        symlink($target, "$source/$symlink")
            or die "couldn't make symlink for testing: $!";

        my $return = system("../src/slack-sync -C $test_config_file role1 2> /dev/null");
        ok(($return == 0 and $? == 0), "symlink sync return");

        ok((!-l "$cache/$symlink"), "cached copy of symlink not a symlink");
        ok((-f "$cache/$symlink"), "cached copy of symlink is a file");
        
        system("cmp $source/$full_target $cache/$symlink >/dev/null 2>&1");
        is($?, 0, "dereferenced symlink contents identical to target file");

        unlink("$source/$symlink")
            or die "couldn't unlink symlink after testing";
        unlink("$cache/$symlink");
    }
}

# Same thing as with role1, but give it a subrole name this time
{
    my $cache = $test_config{cache}."/roles/role2";
    my $source = $test_config{source}."/roles/role2";

    my $return = system("../src/slack-sync -C $test_config_file role2.sub 2> /dev/null");
    ok(($return == 0 and $? == 0), "role2.sub sync return");

    ok((-d $cache), "role2 cache dir created");
    ok((! -d "$cache.sub"), "role2 cache dir not created as role2.sub");

    # Compare the lists of files in the two directories
    my $source_files = {};
    my $cache_files = {};
    find({wanted => gen_wanted($source, $source_files)}, $source);
    find({wanted => gen_wanted($cache, $cache_files)}, $cache);
    is_deeply($cache_files, $source_files, "role2 file list compare");
}

# Now check that using multiple roles works
{
    my $return = system("../src/slack-sync -C $test_config_file @test_roles 2> /dev/null");
    ok(($return == 0 and $? == 0), "multi-role sync return");

    # Compare the lists of files in the two directories
    for my $role (@test_roles) {
        $role =~ s/\..*//; # strip to base role
        my $cache = $test_config{cache}."/roles/$role";
        my $source = $test_config{source}."/roles/$role";
        my $source_files = {};
        my $cache_files = {};
        find({wanted => gen_wanted($source, $source_files)}, $source);
        find({wanted => gen_wanted($cache, $cache_files)}, $cache);
        is_deeply($cache_files, $source_files, "multi-role $role file list compare");
    }
}
