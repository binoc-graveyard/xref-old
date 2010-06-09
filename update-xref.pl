#!/usr/bin/perl
# Run this from cron to update the identifier database that lxr uses
# to turn function names into clickable links.
# Created 12-Jun-98 by jwz.
# Updated 27-Feb-99 by endico. Added multiple tree support.

use Cwd;
use File::Basename;
use lib 'lib';
use LXR::Common;
use LXR::Config;

# we use:
=notes
my used_apps = qw(
mv
time
date
uptime
);
=cut

my $DEBUGGER = '';

my @paths=qw(
/usr/local/bin
/opt/local/bin
/usr/ucb
);

my $TIME = 'time ';
my $UPTIME = 'uptime ';
my $DATE = 'date ';
my $STDERRTOSTDOUT = '2>&1';
my $STDERRTODEVNUL = '2>/dev/null';
my $ERROR_OUTPUT = $STDERRTOSTDOUT;

my $TREE;
my $by_unit = 0;

sub do_mkdir {
  my $dir = shift;
  return if -d $dir;
  die "dangling symlink $dir" if -l $dir;
  mkdir $dir || die "can't create $dir";
}

sub process_args {
  my $was_arg;
  do {
    $was_arg = 0;
    $TREE = shift;
    if ($TREE) {
      if ($TREE eq '-cron') {
        # run from a cron script, silence error output
        $was_arg = 1;
        $TIME = $UPTIME = '';
        $ERROR_OUTPUT = $STDERRTODEVNUL;
      } elsif ($TREE eq '--by-unit') {
        # index each top level directory individually and then merge
        $was_arg = 1;
        $by_unit = 1;
      } else {
        $TREE =~ s{/$}{};
      }
    }
  } while ($TREE && $was_arg);
}

process_args(@ARGV);

my $lxr_dir = '.';
die "can't find $lxr_dir" unless -d $lxr_dir;
my $lxr_conf = "$lxr_dir/lxr.conf";

unless (-f $lxr_conf) {
  die "could not find $lxr_conf";
}

unless (defined $TREE) {
  # need to sniff lxr.conf
  open LXRCONF, "< $lxr_conf" || die "Could not open $lxr_conf";
  while ($line = <LXRCONF>) {
    #since no tree is defined, assume sourceroot is defined the old way
    #grab sourceroot from config file indexing only a single tree where
    #format is "sourceroot: dirname"
    next unless $line =~ /^sourceroot:\s*(\S+)(\s+\S+|)$/;
    if ($2 ne '') {
      $TREE = $1;
    } else {
      $src_dir = $1;
    }
    last;
  }
  close LXRCONF;
}

open HTACCESS, '<', "$lxr_dir/.htaccess";
while ($line = <HTACCESS>) {
    next unless $line =~ /^SetEnv\s+(\S+)\s+(.*)[\r\n]*$/;
    my ($envvar, $value) = ($1, $2);
#SetEnv LD_LIBRARY_PATH /zfsroot/.zfs/snapshot/solex_snv41_eol/usr/sfw/lib:/usr/sfw/lib:/zfsroot/.zfs/snapshot/solex_snv41_eol/usr/local/BerkeleyDB.4.4/lib:/usr/local/BerkeleyDB.4.4/lib
    if ($envvar =~ /PATH/) {
        $value = $ENV{$envvar}.':'.$value;
        $value =~ s/::+/:/g;
    }
    $ENV{$envvar} = $value;
}
close HTACCESS;

# let LXR:: handle lxr.conf
$ENV{'SCRIPT_NAME'} = "/$TREE/" . basename($0);
my ($Conf, $HTTP, $Path, $head) = &init($0);

die "dbdir not set" unless defined $Conf->dbdir;
$db_dir = $Conf->dbdir;
$src_dir = $Conf->sourceroot;
unless (defined $src_dir) {
  die 'Could not find matching sourceroot:'.($TREE ?" for $TREE":'');
}

do_mkdir $db_dir;
$log = "$db_dir/genxref.log";

#exec > $log 2>&1
#XXX what does |set -x| mean?
#system ("set -x > $log");
system ("$DATE >> $log");
$lxr_dir=getcwd;
my $db_tmp_dir="$db_dir/tmp";
unless (-d $db_tmp_dir) {
  do_mkdir $db_tmp_dir;
} else {
  unless (-w $db_tmp_dir) {
    die "can't write to $db_tmp_dir";
  }
  for my $name (qw(xref fileidx)) {
    my $file = "$db_tmp_dir/$name";
    if (-f $file && ! -w $file) {
      die "$file isn't writable.";
    }
  }
}
chdir $db_tmp_dir || die "can't change to $db_tmp_dir";

#XXX what does |set -e| mean?
#system ("set -e >> $log");
my $success = 0;
if ($by_unit) {
  chdir $src_dir;
  my @dirs = sort <*>;
  chdir $db_tmp_dir;
  my ($othertree, $otherpath, $skipdb) = ('', '', '');
  if ($TREE =~ /^(.*)-(?:.*?)$/) {
    $othertree = $1;
    $otherpath = $Conf->{'treehash'}{$othertree};
    for my $tree (keys %{$Conf->{'treehash'}}) {
      my $path = $Conf->{'treehash'}{$tree};
      if ($otherpath eq $path) {
        $skipdb = "$db_dir/../$tree/tmp";
        last if -d $skipdb;
      }
      $skipdb = '';
    }
    unless ($otherpath && -d $otherpath && -d $skipdb) {
      ($othertree, $otherpath, $skipdb) = ('', '', '');
    }
  }

  foreach my $dir (@dirs) {
    my $skip = 0;
    if ($otherpath) {
      $skip = 1 if system("$lxr_dir/compare-dir-trees.pl", "$src_dir/$dir", "$otherpath/$dir") == 0;
    }
    if ($skip) {
      foreach my $file ("$skipdb/fileidx.$dir", "$skipdb/xref.$dir") {
        if (-f $file) {
          system('cp', '-lf', $file, '.');
        }
      }
    } else {
      $success = system("$TIME $DEBUGGER $lxr_dir/genxref $src_dir/$dir default $dir >> $log $ERROR_OUTPUT") == 0;
    }
  }
  $success = system("$TIME $DEBUGGER $lxr_dir/genxref $src_dir merge ".join(' ',@dirs)." >> $log $ERROR_OUTPUT") == 0;
} else {
  $success = system("$TIME $DEBUGGER $lxr_dir/genxref $src_dir >> $log $ERROR_OUTPUT") == 0;
}
if ($success) {
  if (system("chmod", "-R", "a+r", $db_tmp_dir)) {
    die "chmod failed";
  }
  if (system("mv", "$db_tmp_dir/xref", "$db_tmp_dir/fileidx", $db_dir)) {
    die "move failed";
  }
} else {
  open LOG, '>>', $log;
  print LOG 'Error executing genxref
';
  close LOG;
}
chdir "../..";
system ("$DATE >> $log");
system ("$UPTIME >> $log");

exit 0;
