#!/usr/bin/perl -w
# Run this from cron to update the glimpse database that lxr uses
# to do full-text searches.
# Created 12-Jun-98 by jwz.
# Updated 2-27-99 by endico. Added multiple tree support.

use Cwd;
use File::Basename;
use lib 'lib';
use LXR::Common;
use LXR::Config;
use LXR::Shell;

my @paths=qw(
/usr/local/bin
/opt/local/bin
/opt/cvs-tools/bin
/usr/ucb
/usr/local/apache/html/mxr/glimpse
/usr/local/glimpse-4.18.1p/bin
/usr/local/glimpse-3.6/bin
/home/build/glimpse-3.6.src/bin
);

my $STDERRTOSTDOUT = '2>&1';
my $TREE;
my %defaults = qw(
  TIME time
  UPTIME uptime
  DATE date
);

sub do_log {
  my $msg = shift;
  open LOG, '>>', $log;
  print LOG "$msg
";
  close LOG;
}

sub do_and_log {
  my $cmd = shift;
  do_log($cmd);
  system($cmd);
}

sub process_args {
  my $was_arg;
  do {
    $was_arg = 0;
    $TREE = shift;
    if ($TREE) {
      if ($TREE eq '-cron') {
        $was_arg = 1;
        $defaults{TIME} = $defaults{UPTIME} = '';
      }
      $TREE =~ s{/$}{};
    }
  } while ($TREE && $was_arg);
}

process_args(@ARGV);

check_defaults(\%defaults);
my $DATE = $defaults{DATE};
my $TIME = $defaults{TIME};
my $UPTIME = $defaults{UPTIME};

$ENV{'LANG'} = 'C';

# need to consider lxr.conf
if ($ENV{'LXR_CONF'}) {
  $lxr_conf = $ENV{'LXR_CONF'};
} else {
  $lxr_dir = '.';
  die "can't find $lxr_dir" unless -d $lxr_dir;
  my $lxr_conf = "$lxr_dir/lxr.conf";
}

unless (-f $lxr_conf) {
  die "could not find $lxr_conf";
}

my $src_dir;
my $script_prefix = './';
if (defined $TREE) {
  $script_prefix = "/$TREE/";
} else {
  # need to sniff lxr.conf
  open LXRCONF, "< $lxr_conf" || die "Could not open $lxr_conf";
  while ($line = <LXRCONF>) {
    warn "trailing whitespace on line $. {$line}" if $line =~ /^\w+:.*\w.*\s+\n$/;
    #since no tree is defined, assume sourceroot is defined the old way
    #grab sourceroot from config file indexing only a single tree where
    #format is "sourceroot: dirname"
    next unless $line =~ /^sourceroot:\s*(\S+)(\s+\S+|)$/;
    if ($2 ne '') {
      $TREE = $1;
      $ENV{'TREE'} = $TREE;
      $script_prefix = "/$TREE/";
    } else {
      $src_dir = $1;
    }
    last;
  }
  close LXRCONF;
}

# let LXR:: handle lxr.conf
$ENV{'SCRIPT_NAME'} = $script_prefix . basename($0);
my ($Conf, $HTTP, $Path, $head) = &init($0);

{
  my @trees = @{$Conf->{'trees'}};
  die "Could not find tree $TREE" if scalar @trees > 1 && !(grep /^\Q$TREE\E$/, @trees);
}
die "dbdir not set" unless defined $Conf->dbdir;
$db_dir = $Conf->dbdir;
$src_dir = $Conf->sourceroot;

if (defined $Conf->glimpsebin) {
  push @paths, $1 if ($Conf->glimpsebin =~ m{(.*)/([^/]*)$});
}

unless (defined $src_dir) {
  die "could not find sourceroot for tree $TREE";
}

my %pathmap=();
for my $mapitem (@paths) {
$pathmap{$mapitem} = 1;
}
for my $possible_path (keys %pathmap) {
$ENV{'PATH'} = "$possible_path:$ENV{'PATH'}" if -d $possible_path;
}

mkdir $db_dir unless -d $db_dir;
my $pid_lock = get_lock($db_dir, 'xref');
$log = "$db_dir/glimpseindex.log";
#exec > $log 2>&1
#XXX what does |set -x| mean?
#system ("set -x > $log");
=pod
              -e      Exit  immediately  if a simple command (see
                      SHELL GRAMMAR above) exits with a  non-zero
                      status.

              -x      After  expanding  each  simple command, for
                      command, case command, select  command,  or
                      arithmetic   for   command,   display   the
                      expanded value of PS4, followed by the com�
                      mand  and its expanded arguments or associ�
                      ated word list.
=cut

=pod
for my $envvar (keys %ENV) {
print LOG "$envvar=$ENV{$envvar}
";
}
=cut

#system ("date >> $log");
do_log ('date
'.localtime().'
');

unless (-d $src_dir) {
  do_log("$TREE src_dir $src_dir does not exist.");
  exit 4;
}

my $db_dir_tmp = "$db_dir/tmp";
unless (-d $db_dir_tmp) {
  do_log("mkdir $db_dir_tmp");
  unless (mkdir $db_dir_tmp) {
    do_log("mkdir $db_dir_tmp failed");
    exit 5;
  }
}

do_log("chdir $db_dir_tmp");
unless (chdir $db_dir_tmp) {
  do_log("chdir $db_dir_tmp failed");
  exit 6;
}

# do index everything in lxrroot
my @include_paths = qw (

);
unshift @include_paths, $db_dir;
push @include_paths, '';
open GLIMPSEINCLUDE, '>.glimpse_include';
print GLIMPSEINCLUDE join("\n", @include_paths);
close GLIMPSEINCLUDE;

# don't index VCS files
open GLIMPSEEXCLUDE, '>.glimpse_exclude';
my @exclude_paths = qw (
/CVS/
/.hg/
/.git/
/.svn/
/.bzr/
/_MTN/
/obj-
/Regress/
testing/
test/
tests/
gtest/
gtests/
crashtests/
reftest/
mochitest/
mochitests/
jit-tests/
jsapi-tests/
testshell/
testutil/
testsuite/
ctest/
test_
unittest
gmp-test-
sqlite3.c
);
push @exclude_paths, '';
print GLIMPSEEXCLUDE join("\n", @exclude_paths);
close GLIMPSEEXCLUDE;

#XXX what does |set -e| mean?
#system ("set -e >> $log");
#system("time", "glimpseindex", "-H", ".", "$src_dir");
my $cmd = "($TIME glimpseindex -o -n -f -B -M 128 -H . $src_dir $STDERRTOSTDOUT) >> $log";
do_and_log($cmd);
my $mxr_dir_tmp = "$db_dir_tmp/.mxr";
-d $mxr_dir_tmp || mkdir $mxr_dir_tmp;

$cmd = "ls -al >> $log
(cp .glimpse_filenames $mxr_dir_tmp/files $STDERRTOSTDOUT || echo failed to copy .glimpse_filenames) >> $log
ls .mxr -al >> $log
($TIME glimpseindex -H $mxr_dir_tmp $mxr_dir_tmp $STDERRTOSTDOUT) >> $log
";
do_and_log($cmd);
if (-f "$mxr_dir_tmp/.glimpse_filenames") {
  $cmd = "
perl -pi -e 's{tmp/\.mxr}{\.mxr}' $mxr_dir_tmp/.glimpse_filenames
glimpseindex -H $mxr_dir_tmp -R $STDERRTOSTDOUT >> $log";
  do_and_log($cmd);
} else {
  do_log("could not find .mxr/.glimpse_filenames");
}

# build filename index
# shared w/ update-root.pl
do_log('chmod -R a+r .');
system("chmod", "-R", "a+r", ".");
$cmd = "mv .glimpse* ../";
if (-d $mxr_dir_tmp) {
  $cmd = 'mv .glimpse* .mxr ../';
  if (-d '../.mxr') {
    $cmd = "
mv ../.mxr ../.mxr-old
$cmd
rm -rf ../.mxr-old
";
  }
}
do_and_log($cmd);

do_log('cd ../..');
chdir '../..';
do_log(
'date
'.localtime()."
$UPTIME
");
system ("$UPTIME >> $log") if $UPTIME =~ /\w/;

unlink $pid_lock;
exit 0;
