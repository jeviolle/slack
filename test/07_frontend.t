#!/usr/bin/perl -w

use strict;
use warnings FATAL => qw(all);
use Test::More tests => 13;
use test_util;
import test_util qw(gen_wanted);

use File::Find;
use File::Path;
use Cwd;

# For the scripts we will run
my $srcdir = getcwd."/../src";
$ENV{PERL5LIB} = $srcdir;

# First, just do all the roles in the config file
{
  my $root = $test_config{root};
  my $source = "$test_config{source}/roles";
  rmtree($root);
  die "Could not remove root before testing" if -e $root;

  my $return = system("../src/slack --libexec-dir=$srcdir -C $test_config_file >/dev/null 2>&1");
  ok(($return == 0 and $? == 0), "slack return");
  # Make sure all the files are installed
  my $source_files = {};
  my $root_files = {};

  # Generate a list of all files in all roles in source
  for my $role (@test_roles) {
    my @role_parts = split(/\./, $role);
    # build up the role, piece by piece
    my @partial_role = ();
    while (defined (my $part = shift @role_parts)) {
      push @partial_role, $part;
      my $source = "$test_config{source}/roles/$partial_role[0]/files";
      # this generates ../role/files
      #                ../role/files.sub
      #                ../role/files.sub.sub
      # as subs get pushed onto @partial_role
      if (scalar @partial_role > 1) {
        $source .= join(".", ("", @partial_role[1..$#partial_role]));
      }
      find({wanted => gen_wanted($source, $source_files)},
          $source);
    }
  }
  # Also, role2 makes a /tmp/postinstall
  $source_files->{'tmp'} = 'd';
  $source_files->{'tmp/postinstall'} = 'f';

  find({wanted => gen_wanted($root, $root_files)},
      $root);
  is_deeply($root_files, $source_files, "slack file list compare");
}

# Next, let's try role2 with no scripts
{
  my $root = $test_config{root};
  my $source = "$test_config{source}/roles/role2/files";
  rmtree($root);
  die "Could not remove root before testing" if -e $root;

  my $return = system("../src/slack --libexec-dir=$srcdir -C $test_config_file --no-scripts role2  >/dev/null 2>&1");
  ok(($return == 0 and $? == 0), "slack --no-scripts return");
  # Make sure all the files are installed
  my $source_files = {};
  my $root_files = {};

  find({wanted => gen_wanted($source, $source_files)},
      $source);
  find({wanted => gen_wanted($root, $root_files)},
      $root);
  is_deeply($root_files, $source_files, "slack --no-scripts");
}

# Next, let's try role2 with no files
{
  my $root = $test_config{root};
  my $source = "$test_config{source}/roles/role2/files";
  rmtree($root);
  die "Could not remove root before testing" if -e $root;
  mkpath($root);
  die "Could not create root before testing" if not -e $root;

  my $return = system("../src/slack --libexec-dir=$srcdir -C $test_config_file --no-files role2  >/dev/null 2>&1");
  ok(($return == 0 and $? == 0), "slack --no-files return");

  # Only these files should exist
  my $source_files = {
      'tmp' => 'd',
      'tmp/postinstall' => 'f',
  };
  my $root_files = {};

  find({wanted => gen_wanted($root, $root_files)},
      $root);
  is_deeply($root_files, $source_files, "slack --no-files");
}

# Next, role2 with no sync at all
{
  my $root = $test_config{root};
  my $cache = "$test_config{cache}/roles/role2";
  rmtree($root);
  die "Could not remove root before testing" if -e $root;
  mkpath($root);
  die "Could not create root before testing" if not -e $root;
  rmtree($cache);
  die "Could not remove cache before testing" if -e $cache;
  mkpath("$cache/files");
  die "Could not create cache before testing" if not -e "$cache/files";

  my $testfile = 'foo';
  open(FOO, ">", "$cache/files/$testfile")
    or die "open $cache/files/$testfile: $!";
  print FOO "foo\n";
  close(FOO)
    or die "close $cache/files/$testfile: $!";

  my $return = system("../src/slack --libexec-dir=$srcdir -C $test_config_file --no-sync role2  >/dev/null 2>&1");
  ok(($return == 0 and $? == 0), "slack --no-sync return");

  # Only these files should exist
  my $source_files = {
      $testfile => 'f',
  };
  my $root_files = {};

  find({wanted => gen_wanted($root, $root_files)},
      $root);
  is_deeply($root_files, $source_files, "slack --no-sync");
}

# Make sure errors are propagated properly
{
  my $output = `../src/slack --libexec-dir=$srcdir -C $test_config_file runscript  2>&1`;
  isnt($?, 0, "slack errors propagated");
  like($output, qr/^FATAL\[slack\]:.*exited 1/m, "correct error message");
}
# Make sure verbosity is propagated properly
{
  my $output;
  $output = `../src/slack --libexec-dir=$srcdir -C $test_config_file role1 2>&1`;
  # this checks for lines that aren't complaining about not being superuser
  unlike($output, qr/^(?!WARNING\[\S+\]: Not superuser)/m, "no -v quiet");

  $output = `../src/slack --libexec-dir=$srcdir -C $test_config_file -v role1 2>&1`;
  unlike($output, qr/^slack-\w+:/m, "one -v not propagated");
  $output = `../src/slack --libexec-dir=$srcdir -C $test_config_file -vv role1 2>&1`;
  like($output, qr/^slack-\w+:/m, "two -v propagated");
}
