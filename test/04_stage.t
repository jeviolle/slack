#!/usr/bin/perl -w

use strict;
use warnings FATAL => qw(all);
use Test::More tests => 15;
use test_util;
import test_util qw(gen_wanted);

use File::Find;
use File::Path;

# For the scripts we will run
$ENV{PERL5LIB} = '../src';

# get rid of the stage
rmtree($test_config{stage});
die "Could not remove stage for testing" if (-e $test_config{stage});

# First, we're playing around with role1
{
  my $role = 'role1';
  my $cache = $test_config{cache}."/roles";
  my $stage = $test_config{stage}."/roles";
  my $test_time = 1200000000;

  my $overridden_file = "/etc/$role.conf";
  my $src1 = "$cache/$role/files/$overridden_file";
  my $src2 = "$cache/$role/files.sub/$overridden_file";
  my $dst = "$stage/$role.sub/files/$overridden_file";

  # sync the role so we've got something known to work with
  (system("../src/slack-sync -C $test_config_file $role 2> /dev/null") == 0)
      or die "Couldn't sync $role for testing"; 
  # set up the source so the overridden files have the same timestamp
  utime($test_time, $test_time, $src1, $src2)
      or die "Couldn't touch $src1 and $src2 for testing";

  {
    # Now run the stage
    my $return = system("../src/slack-stage -C $test_config_file $role 2> /dev/null");
    ok(($return == 0 and $? == 0), "$role stage return");

    ok((-d $stage), "$role stage dir created");

    # Compare the lists of files in the two directories
    {
      my $cache_files = {};
      my $stage_files = {};
      find({wanted => gen_wanted("$cache/$role/files", $cache_files)},
          "$cache/$role/files");
      find({wanted => gen_wanted("$stage/$role/files", $stage_files)},
          "$stage/$role/files");
      is_deeply($stage_files, $cache_files, "$role file list compare");
    }
  }

  {
    my $return = system("../src/slack-stage -C $test_config_file $role.sub 2> /dev/null");
    ok(($return == 0 and $? == 0), "$role.sub stage return");

    ok((-d $stage), "$role.sub stage dir created");

    # Compare the lists of files in the two directories
    {
      my $cache_files = {};
      my $stage_files = {};
      # The stage should have a union of files + files.sub from the cache
      find({wanted => gen_wanted("$cache/$role/files", $cache_files)},
          "$cache/$role/files");
      find({wanted => gen_wanted("$cache/$role/files.sub", $cache_files)},
          "$cache/$role/files.sub");
      # The stage is in "role.sub" instead of "role" for subroles
      find({wanted => gen_wanted("$stage/$role.sub/files", $stage_files)},
          "$stage/$role.sub/files");
      is_deeply($stage_files, $cache_files, "$role.sub file list compare");
    }

    # Check that the file in the subrole overrode the file in the base role
    {
      system("cmp $src2 $dst >/dev/null 2>&1");
      is($?, 0, "files in subrole override files in base role");
    }

    # Check that the time on the overridden file is copied from the cache
    {
      my $mtime = (stat $dst)[9];
      is($mtime, $test_time, "timestamp copied from cache");
    }
  }

  {
    # Make some junk in the stage
    my $testfile = "$stage/$role/files/should_not_be_here";
    my $testdir = "$stage/$role/scripts";
    open(TEST, ">", $testfile)
      or die "open $testfile: $!";
    print TEST "This should be deleted\n";
    close(TEST)
      or die "close $testfile: $!";
    mkpath($testdir); # will throw exception on failure

    my $return = system("../src/slack-stage -C $test_config_file $role 2> /dev/null");
    ok(($return == 0 and $? == 0), "$role stage return");

    ok((not -e $testfile), "junk file deleted");
    ok((not -e $testdir), "junk scripts dir deleted");
  }
}

# Just make sure multiple subroles work as expected for role3
{
  my $role = 'role3';
  my $cache = $test_config{cache}."/roles";
  my $stage = $test_config{stage}."/roles";

  # sync the role so we've got something known to work with
  (system("../src/slack-sync -C $test_config_file $role 2> /dev/null") == 0)
      or die "Couldn't sync $role for testing"; 

  {
    my $return = system("../src/slack-stage -C $test_config_file $role.sub.sub 2> /dev/null");
    ok(($return == 0 and $? == 0), "$role.sub stage return");

    ok((-d $stage), "$role.sub cache dir created");

    # Compare the lists of files in the two directories
    {
      my $cache_files = {};
      my $stage_files = {};
      # The stage should have a union of files + files.sub from the cache
      find({wanted => gen_wanted("$cache/$role/files", $cache_files)},
          "$cache/$role/files");
      find({wanted => gen_wanted("$cache/$role/files.sub", $cache_files)},
          "$cache/$role/files.sub");
      find({wanted => gen_wanted("$cache/$role/files.sub.sub", $cache_files)},
          "$cache/$role/files.sub.sub");
      # The stage is in "role.sub" instead of "role" for subroles
      find({wanted => gen_wanted("$stage/$role.sub.sub/files", $stage_files)},
          "$stage/$role.sub.sub/files");
      is_deeply($stage_files, $cache_files, "$role.sub.sub file list compare");
    }
    # role3 has no scripts

    # Check that the file in the subrole overrode the file in the base role
    {
      my $overridden_file = "/etc/$role.conf";
      my $src = "$cache/$role/files.sub.sub/$overridden_file";
      my $dst = "$stage/$role.sub.sub/files/$overridden_file";
      system("cmp $src $dst >/dev/null 2>&1");
      is($?, 0, "files in double subrole override files in base role");
    }
  }
}
