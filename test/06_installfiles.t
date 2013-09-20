#!/usr/bin/perl -w

use strict;
use warnings FATAL => qw(all);
use Test::More tests => 13;
use test_util;
import test_util qw(gen_wanted);

use File::Find;
use File::Path;

# For the scripts we will run
$ENV{PERL5LIB} = '../src';

my @roles = qw(role1);
# sync the role so we've got something known to work with
(system("../src/slack-sync -C $test_config_file @roles 2> /dev/null") == 0)
  or die "Couldn't sync roles for testing"; 
# sync the role so we've got something known to work with
(system("../src/slack-stage -C $test_config_file @roles 2> /dev/null") == 0)
  or die "Couldn't stage roles for testing"; 

# First, we're playing around with role1
{
  my $role = $roles[0];
  my $stage = $test_config{stage}."/roles/$role/files";
  my $root = $test_config{root};


  # Make sure all the files are installed
  {
    rmtree($root);
    die "Could not remove root before testing" if -e $root;

    # pretend /etc is to be installed with revolutionary perms
    my $testdirperms = 01776;
    my $testdir = "etc";
    chmod $testdirperms, "$stage/$testdir"
      or die "Could not chmod $testdirperms $stage/$testdir: $!";

    # something less wacky for a conf file
    my $testfileperms = 0440;
    my $testfile = "etc/$role.conf";
    chmod $testfileperms, "$stage/$testfile"
      or die "Could not chmod $testfileperms $stage/$testfile: $!";

    # Now run the install
    my $return = system("../src/slack-installfiles -C $test_config_file $role 2> /dev/null");
    ok(($return == 0 and $? == 0), "$role installfiles return");
    ok((-d $root), "$role root dir created");

    is(((stat "$root/$testdir")[2] & 07777), $testdirperms,
       "new dir mode preserved");
    is(((stat "$root/$testfile")[2] & 07777), $testfileperms,
       "new file mode preserved");
    # Compare the lists of files in the two directories
    {
      my $stage_files = {};
      my $root_files = {};
      find({wanted => gen_wanted($stage, $stage_files)},
          $stage);
      find({wanted => gen_wanted($root, $root_files)},
          $root);
      is_deeply($root_files, $stage_files, "$role file list compare");
    }
    # role1 has no scripts
  }

  # Test that files are not deleted
  {
    my $testdir = "$root/etc";
    my $testperms = 0715;
    rmtree($testdir);
    die "Could not rmtree $testdir" if (-e $testdir);
    mkdir $testdir
        or die "Could not mkdir $testdir: $!";
    chmod $testperms, $testdir
        or die "Could not chmod $testdir: $!";
    
    my $testfile = "$root/etc/existing_file";
    open(FILE, ">", $testfile)
        or die "Could not create $testfile: $!";
    close(FILE)
        or die "Could not close $testfile: $!";

    my $return = system("../src/slack-installfiles -C $test_config_file $role 2> /dev/null");
    ok(($return == 0 and $? == 0), "$role installfiles return");

    is(((stat $testdir)[2] & 07777), $testperms, "existing dir perms preserved");
    ok((-f $testfile), "existing file preserved");
  }

  # Test that backups are made
  {
    rmtree($test_config{'backup-dir'});
    die "Could not rmtree $test_config{'backup-dir'}"
        if (-e $test_config{'backup-dir'});

    my $testfile = "etc/$role.conf";
    chmod 0644, "$root/$testfile"
        or die "Could not chmod 0644 $root/$testfile: $!";
    open(TESTFILE, ">", "$root/$testfile")
        or die "Could not open $root/$testfile for writing: $!";
    print TESTFILE "Some edits an admin made locally\n";
    close(TESTFILE)
        or die "Could not close $root/$testfile: $!";

    my $return = system("../src/slack-installfiles -C $test_config_file --backup --backup-dir=$test_config{'backup-dir'} $role 2> /dev/null");
    ok(($return == 0 and $? == 0), "$role installfiles return");

    ok((-f $test_config{'backup-dir'}."/".$testfile),
        "backup file created when file changed");

    # Now remove the file and make sure it's not re-created when we haven't
    # modified the file.
    rmtree($test_config{'backup-dir'});
    die "Could not rmtree $test_config{'backup-dir'}"
        if (-e $test_config{'backup-dir'});
    $return = system("../src/slack-installfiles -C $test_config_file --backup --backup-dir=$test_config{'backup-dir'} $role 2> /dev/null");
    ok(($return == 0 and $? == 0), "$role installfiles return");

    ok((not -f $test_config{'backup-dir'}."/".$testfile),
        "backup file not created when file not changed");
  }


  # Test that we succeed when no files to install
  {
    rmtree($stage);
    die "Could not remove stage before testing" if -e $stage;

    # Now run the install
    my $return = system("../src/slack-installfiles -C $test_config_file $role 2> /dev/null");
    ok(($return == 0 and $? == 0), "succeed on missing files dir");
  }
}
