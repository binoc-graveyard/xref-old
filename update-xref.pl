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

sub process_args {
  my $was_arg;
  do {
    $was_arg = 0;
    $TREE = shift;
    if ($TREE) {
      if ($TREE eq '-cron') {
        $was_arg = 1;
        $TIME = $UPTIME = '';
        $ERROR_OUTPUT = $STDERRTODEVNUL;
      }
      $TREE =~ s{/$}{};
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
        $value =~ s/::/:/g;
    }
    $ENV{$envvar} = $value;
}
close HTACCESS;

# let LXR:: handle lxr.conf
$ENV{'SCRIPT_NAME'} = "/$TREE/" . basename($0);
my ($Conf, $HTTP, $Path, $head) = &init($0);

$db_dir = $Conf->dbdir;
$src_dir = $Conf->sourceroot;

mkdir $db_dir unless -d $db_dir;
$log = "$db_dir/genxref.log";

#exec > $log 2>&1
#XXX what does |set -x| mean?
#system ("set -x > $log");
system ("$DATE >> $log");
$lxr_dir=getcwd;
my $db_tmp_dir="$db_dir/tmp";
if (-d $db_tmp_dir) {
  mkdir $db_tmp_dir || die "can't make $db_tmp_dir";
} else {
  unless (-w $db_tmp_dir) {
    die "can't write to $db_tmp_dir";
  }
  for my $f (qw(xref fileidx)) {
    $f = "$db_tmp_dir/$f";
    if (-f $f && ! -w $f) {
      die "$f isn't writable.";
    }
  }
}
chdir $db_tmp_dir || die "can't change to $db_tmp_dir";

#XXX what does |set -e| mean?
#system ("set -e >> $log");
if (system("$TIME $lxr_dir/genxref $src_dir >> $log $ERROR_OUTPUT") == 0) {
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
