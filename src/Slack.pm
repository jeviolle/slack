# $Id: Slack.pm 189 2008-04-21 00:52:56Z sundell $
# vim:sw=2
# vim600:fdm=marker
# Copyright (C) 2004-2008 Alan Sundell <alan@sundell.net>
# All Rights Reserved.  This program comes with ABSOLUTELY NO WARRANTY.
# See the file COPYING for details.

package Slack;

require 5.006;
use strict;
use Carp qw(cluck confess croak);
use File::Find;
use POSIX qw(WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG);

use base qw(Exporter);
use vars qw($VERSION @EXPORT @EXPORT_OK $DEFAULT_CONFIG_FILE);
$VERSION = '0.15.2';
@EXPORT    = qw();
@EXPORT_OK = qw();

$DEFAULT_CONFIG_FILE = '/etc/slack.conf';

my $term;

my @default_options = (
    'help|h|?',
    'version',
    'verbose|v+',
    'quiet',
    'config|C=s',
    'source|s=s',
    'rsh|e=s',
    'cache|c=s',
    'stage|t=s',
    'root|r=s',
    'dry-run|n',
    'backup|b',
    'backup-dir=s',
    'hostname|H=s',
);

sub default_usage ($) {
  my ($synopsis) = @_;
  return <<EOF;
Usage: $synopsis

Options:
  -h, -?, --help
      Print this help message and exit.

  --version
      Print the version number and exit.

  -v, --verbose
      Be verbose.

  --quiet
      Don't be verbose (Overrides previous uses of --verbose)

  -C, --config  FILE
      Use this config file instead of '$DEFAULT_CONFIG_FILE'.

  -s, --source  DIR
      Source for slack files

  -e, --rsh  COMMAND
      Remote shell for rsync

  -c, --cache  DIR
      Local cache directory for slack files

  -t, --stage  DIR
      Local staging directory for slack files

  -r, --root  DIR
      Root destination for slack files

  -n, --dry-run
      Don't write any files to disk -- just report what would have been done.

  -b, --backup
      Make backups of existing files in ROOT that are overwritten.

  --backup-dir  DIR
      Put backups into this directory.

  -H, --hostname  HOST
      Pretend to be running on HOST, instead of the name given by
        gethostname(2).
EOF
}
# Read options from a config file.  Arguments:
#       file    => config file to read
#       opthash => hashref in which to store the options
#       verbose => whether to be verbose
sub read_config (%) {
  my %arg = @_;
  my ($config_fh);
  local $_;

  confess "Slack::read_config: no config file given"
    if not defined $arg{file};
  $arg{opthash} = {}
    if not defined $arg{opthash};

  open($config_fh, '<', $arg{file})
    or confess "Could not open config file '$arg{file}': $!";

  # Make this into a hash so we can quickly see if we're looking
  # for a particular option
  my %looking_for;
  if (ref $arg{options} eq 'ARRAY') {
    %looking_for = map { $_ => 1 } @{$arg{options}};
  }

  while(<$config_fh>) {
    chomp;
    s/#.*//; # delete comments
    s/\s+$//; # delete trailing spaces
    next if m/^$/; # skip empty lines

    if (m/^[A-Z_]+=\S+/) {
      my ($key, $value) = split(/=/, $_, 2);
      $key =~ tr/A-Z_/a-z-/;
      # Only set options we're looking for
      next if (%looking_for and not $looking_for{$key});
      # Don't set options that are already set
      next if defined $arg{opthash}->{$key};

      $arg{verbose} and print STDERR "Slack::read_config: Setting '$key' to '$value'\n";
      $arg{opthash}->{$key} = $value;
    } else {
      cluck "Slack::read_config: Garbage line '$_' in '$arg{file}' line $. ignored";
    }
  }

  close($config_fh)
    or confess "Slack::read_config: Could not close config file: $!";

  # The verbose option is treated specially in so many places that
  # we need to make sure it's defined.
  $arg{opthash}->{verbose} ||= 0;

  return $arg{opthash};
}

# Just get the exit code from a command that failed.
# croaks if anything weird happened.
sub get_system_exit (@) {
  my @command = @_;

  if (WIFEXITED($?)) {
    my $exit = WEXITSTATUS($?);
    return $exit if $exit;
  }
  if (WIFSIGNALED($?)) {
    my $sig = WTERMSIG($?);
    croak "'@command' caught sig $sig";
  }
  if ($!) {
    croak "Syserr on system '@command': $!";
  }
  croak "Unknown error on '@command'";
}

sub check_system_exit (@) {
  my @command = @_;
  my $exit = get_system_exit(@command);
  # Exit is non-zero if get_system_exit() didn't croak.
  croak "'@command' exited $exit";
}

# get options from the command line and the config file
# Arguments
#       opthash => hashref in which to store options
#       usage   => usage statement
#       required_options => arrayref of options to require -- an exception
#               will be thrown if these options are not defined
#       command_line_hash => store options specified on the command line here
sub get_options {
  my %arg = @_;
  use Getopt::Long;
  Getopt::Long::Configure('bundling');

  if (not defined $arg{opthash}) {
    $arg{opthash} = {};
  }

  if (not defined $arg{usage}) {
    $arg{usage} = default_usage($0);
  }

  my @extra_options = ();  # extra arguments to getoptions
  if (defined $arg{command_line_options}) {
    @extra_options = @{$arg{command_line_options}};
  }

  # Make a --quiet function that turns off verbosity
  $arg{opthash}->{quiet} = sub { $arg{opthash}->{verbose} = 0; };

  unless (GetOptions($arg{opthash},
                    @default_options,
                    @extra_options,
                    )) {
    print STDERR $arg{usage};
    exit 1;
  }
  if ($arg{opthash}->{help}) {
    print $arg{usage};
    exit 0;
  }

  if ($arg{opthash}->{version}) {
    print "slack version $VERSION\n";
    exit 0;
  }

  # Get rid of the quiet handler
  delete $arg{opthash}->{quiet};

  # If we've been given a hashref, save our options there at this
  # stage, so the caller can see what was passed on the command line.
  # Unfortunately, perl has no .replace function, so we iterate.
  if (ref $arg{command_line_hash} eq 'HASH') {
    while (my ($k, $v) = each %{$arg{opthash}}) {
      $arg{command_line_hash}->{$k} = $v;
    }
  }

  # Use the default config file
  if (not defined $arg{opthash}->{config}) {
    $arg{opthash}->{config} = $DEFAULT_CONFIG_FILE;
  }

  # We need to decide whether to be verbose about reading the config file
  # Currently we just do it if global verbosity > 2
  my $verbose_config = 0;
  if (defined $arg{opthash}->{verbose}
      and $arg{opthash}->{verbose} > 2) {
    $verbose_config = 1;
  }

  # Read options from the config file, passing along the options we've
  # gotten so far
  read_config(
      file => $arg{opthash}->{config},
      opthash => $arg{opthash},
      verbose => $verbose_config,
  );

  # The "verbose" option gets compared a lot and needs to be defined
  $arg{opthash}->{verbose} ||= 0;

  # The "hostname" option is set specially if it's not defined
  if (not defined $arg{opthash}->{hostname}) {
    use Sys::Hostname;
    $arg{opthash}->{hostname} = hostname;
  }

  # We can require some options to be set
  if (ref $arg{required_options} eq 'ARRAY') {
    for my $option (@{$arg{required_options}}) {
      if (not defined $arg{opthash}->{$option}) {
        croak "Required option '$option' not given on command line or specified in config file!\n";
      }
    }
  }

  return $arg{opthash};
}

sub prompt ($) {
  my ($prompt) = @_;
  if (not defined $term) {
    require Term::ReadLine;
    $term = new Term::ReadLine 'slack'
  }

  $term->readline($prompt);
}


# Calls the callback on absolute pathnames of files in the source directory,
# and also on names of directories that don't exist in the destination
# directory (i.e. where $source/foo exists but $destination/foo does not).
sub find_files_to_install ($$$) {
  my ($source, $destination, $callback) = @_;
  return find ({
      wanted => sub {
        if (-l or not -d _) {
          # Copy all files, links, etc
          my $file = $File::Find::name;
          &$callback($file);
        } elsif (-d _) {
          # For directories, we only want to copy it if it doesn't
          # exist in the destination yet.
          my $dir = $File::Find::name;
          # We know the root directory will exist (we make it above),
          # so skip the base of the source
          (my $short_source = $source) =~ s#/$##;
          return if $dir eq $short_source;

          # Strip the $source from the path,
          # so we can build the destination dir from it.
          my $subdir = $dir;
          ($subdir =~ s#^$source##)
            or croak "sub failed: $source|$subdir";

          if (not -d "$destination/$subdir") {
            &$callback($dir);
          }
        }
      }
    },
    $source,
  );
}

# Runs rsync with the necessary redirection to its filehandles
sub wrap_rsync (@) {
  my @command = @_;
  my ($pid);

  if ($pid = fork) {
    # Parent
  } elsif (defined $pid) {
    # Child
    open(STDIN, "<", "/dev/null")
      or die "Could not redirect STDIN from /dev/null\n";
    # This redirection is necessary because rsync sends
    #   verbose output to STDOUT
    open(STDOUT, ">&STDERR")
      or die "Could not redirect STDOUT to STDERR\n";
    exec(@command);
    die "Could not exec '@command': $!\n";
  } else {
    die "Could not fork: $!\n";
  }

  my $kid = waitpid($pid, 0);
  if ($kid != $pid) {
    die "waitpid returned $kid\n";
  } elsif ($?) {
    Slack::check_system_exit(@command);
  }
}

# Runs rsync with the necessary redirection to its filehandles, but also
# returns an FH to stdin and a PID.
sub wrap_rsync_fh (@) {
  my @command = @_;
  my ($fh, $pid);

  if ($pid = open($fh, "|-")) {
    # Parent
  } elsif (defined $pid) {
    # Child
    # This redirection is necessary because rsync sends
    #   verbose output to STDOUT
    open(STDOUT, ">&STDERR")
      or die "Could not redirect STDOUT to STDERR\n";
    exec(@command);
    die "Could not exec '@command': $!\n";
  } else {
    die "Could not fork: $!\n";
  }
  return($fh, $pid);
}

1;
