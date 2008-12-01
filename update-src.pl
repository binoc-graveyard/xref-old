#!/usr/bin/perl -w
# Run this from cron to update the source tree that lxr sees.
# Created 12-Jun-98 by jwz.
# Updated 27-Feb-99 by endico. Added multiple tree support.

use Cwd;
use File::Basename;
use lib 'lib';
use LXR::Common;
use LXR::Config;

my @paths=qw(
/opt/local/bin
/opt/cvs-tools/bin
/usr/ucb
/usr/local/apache/html/mxr/glimpse
/usr/local/glimpse-4.18.1p/bin
/usr/local/glimpse-3.6/bin
/home/build/glimpse-3.6.src/bin
);

my $CVSROOT=':pserver:anonymous@cvs-mirror.mozilla.org:/cvsroot';

$ENV{PATH}='/opt/local/bin:/opt/cvs-tools/bin:'.$ENV{PATH};

my ($lxr_dir, $lxr_conf, $db_dir, $src_dir, $Conf, $HTTP, $Path, $head);

my $TIME = 'time ';
my $UPTIME = 'uptime ';
my $DATE = 'date ';
my $STDERRTOSTDOUT = '2>&1';
my $STDERRTODEVNUL = '2>/dev/null';
my $ERROR_OUTPUT = $STDERRTOSTDOUT;

my $CVS = 'cvs ';
my $CVSQUIETFLAGS = '-Q ';
my $CVSROOTFLAGS = "-d $CVSROOT ";
my $CVSCO = 'checkout ';
my $CVSUP = 'update ';
my $CVSCOMMAND = "$CVS $CVSQUIETFLAGS $CVSROOTFLAGS";

my $SVN = 'svn ';
my $SVNQUIETFLAGS = '--non-interactive ';
my $SVNCO = 'checkout ';
my $SVNUP = 'update ';
my $SVNCOMMAND = "$SVN $SVNQUIETFLAGS";

my $HGCOMMAND = 'hg ';
my $HGCLONE = 'clone ';
my $HGUP = 'up ';
my $HGUPDATE = 'pull -u -r default';

sub hg_get_list
{
    my ($dir) = @_;
    my @dirs;
    open LIST, "curl -s -f $dir|" || return @dirs;
    while (<LIST>) { 
        if (m{class="list" href="[^"]*/([^"/]+)/"}) {
            push @dirs, $1;
        }
    }
    return @dirs;
}

sub hg_clone_cheap
{
    my ($ver, $prefix, $base, $dest, $extra) = @_;
    $extra = '' unless defined $extra;
    my $orig = $Conf->{'treehash'}{$base}.$extra;
    my ($destextra, $prefixextra) = ($dest.$extra, $prefix.$extra);
    if (-d "$orig/.hg") {
        my $tag = $ver;
        $tag =~ s/\./_/g;
        $tag = 'GECKO_'.$tag.'_BASE';
        my $command =
          "[ -d $destextra ] && rmdir $destextra; cd $orig;".
          "$TIME ($HGCOMMAND $HGCLONE .#$tag $destextra || $HGCOMMAND $HGCLONE . $destextra) $STDERRTOSTDOUT;".
          "cd $destextra;".
          "perl -pi -e 's!default =.*!default = http://hg.mozilla.org/releases/$prefixextra!' .hg/hgrc;".
          "$TIME $HGCOMMAND $HGUP $STDERRTOSTDOUT;";
        print LOG $command;
        print LOG `$command`;
        my $rev;
        while (($rev = `cd $destextra; hg out --template="{node|short}\n" -l 1|head -3|tail -1`)
               && $rev !~ /no changes found/) {
             `cd $destextra; hg strip -f -n $rev`;
        }
    } else {
        my $src = basename($dest);
        print LOG `cd $src; $TIME $HGCOMMAND $HGCLONE http://hg.mozilla.org/releases/$prefixextra $STDERRTOSTDOUT`;
    }
}

my $EACHONE = 'xargs -n1 ';

my $BZR = 'bzr ';
my $BZRQUIETFLAGS = '-q ';
my $BZRUPDATE = 'update $BZRQUIETFLAGS';

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

$lxr_dir = '.';
die "can't find $lxr_dir" unless -d $lxr_dir;
$lxr_conf = "$lxr_dir/lxr.conf";

# let LXR:: handle lxr.conf
if (defined $TREE) {
  $ENV{'SCRIPT_NAME'} = "/$TREE/" . basename($0);
  ($Conf, $HTTP, $Path, $head) = &init($0);
  $db_dir = $Conf->dbdir;
  $src_dir = $Conf->sourceroot;
  die "Could not find sourceroot for $TREE" unless defined $src_dir;

  if (defined $Conf->glimpsebin) {
    push @paths, $1 if ($Conf->glimpsebin =~ m{(.*)/([^/]*)$});
  }
} else {
  open LXRCONF, '<', "$lxr_dir/lxr.conf" || die "can't open lxr.conf";
  my %sourceroot = ();
  do { 
    #grab sourceroot from config file indexing only a single tree where
    #format is "sourceroot: dirname"

    #grab sourceroot from config file indexing multiple trees where
    #format is "sourceroot: treename dirname"

    $line = <LXRCONF>;
    $db_dir = "$1" if $line =~ /^dbdir:\s*(.*)$/;
    $sourceroot{$1} = $2 if $line =~ /^sourceroot:\s*(\S+ |)(.*)/;
  } until eof LXRCONF;
  die "could not find dbdir: directive"  unless defined $db_dir;
  $db_dir .= "/$TREE" if defined $TREE && $TREE ne '';

  #since no tree is defined, assume sourceroot is defined the old way
  $src_dir = $sourceroot{$TREE ? "$TREE " : ''};
}
unless (defined $src_dir) {
  die "could not find matching sourceroot:" .($TREE ? " for $TREE" :'');
}

my %pathmap=();
for my $mapitem (@paths) {
  $pathmap{$mapitem} = 1;
}
for my $possible_path (keys %pathmap) {
  $ENV{'PATH'} = "$possible_path:$ENV{'PATH'}" if -d $possible_path;
}

-d $db_dir || mkdir $db_dir;
my $log="$db_dir/cvs.log";

open LOG, '>', $log || die "can't open $log";
#print LOG `set -x`;
print LOG `date`;
print LOG `pwd`;

# then update the Mozilla sources
-d $src_dir || mkdir $src_dir;
chdir $src_dir;
chdir '..';

# endico: check out the source
for ($TREE) {
    /^world-all$/ && do {
        print LOG `$TIME (echo */* | $EACHONE $SVNCOMMAND $SVNUP)`;
        last;
    };
    /^classic$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P -rMozillaSourceClassic_19981026_BRANCH MozillaSource $STDERRTOSTDOUT`;
        last; 
    };
    /^js$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P mozilla/js mozilla/js2 mozilla/nsprpub $STDERRTOSTDOUT`;
        last;
    };
    /^security$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P mozilla/security mozilla/nsprpub $STDERRTOSTDOUT`;
        last;
    };
    /^webtools$/ && do {
        chdir '..';
        print LOG `$TIME $CVSCOMMAND $CVSCO -P mozilla/webtools $STDERRTOSTDOUT`;
        last;
    };
    /^bugzilla(?:\d.*|)$/ && do {
        chdir '../..';
        print LOG `$TIME $CVSCOMMAND $CVSCO -P mozilla/webtools/bugzilla $STDERRTOSTDOUT`;
        last;
    };
    /^(?:l10n|l10n-(?:mozilla1\.8|aviarybranch|mozilla1\.8\.0))$/ && do {
        print LOG `$TIME $CVS $CVSQUIETFLAGS -d ':pserver:anonymous\@cvs-mirror.mozilla.org:/l10n' $CVSUP -dP $STDERRTOSTDOUT`;
        last;
    };
    /^mobile-browser$/ && do {
        print LOG `cd $src_dir; $TIME $HGCOMMAND $HGUPDATE $STDERRTOSTDOUT`;
        last;
    };
    /^mozilla$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P mozilla $STDERRTOSTDOUT`;
        last;
    };
    /^mozillasvn-all$/ && do {
        print LOG `$TIME $SVNCOMMAND $SVNUP svn.mozilla.org $STDERRTOSTDOUT`;
        last;
    };
    /^mozillausers-central$/ && do {
        my @dirs = <$src_dir/*/*>;
        foreach my $dir (@dirs) {
            print LOG `cd $dir; $TIME $HGCOMMAND $HGUPDATE $STDERRTOSTDOUT`;
        }
        last;
    };
    /^(?:build|incubator|l10n|labs|webtools)-central$/ && do {
        my @dirs = <$src_dir/*>;
        foreach my $dir (@dirs) {
            print LOG `cd $dir; $TIME $HGCOMMAND $HGUPDATE $STDERRTOSTDOUT`;
        }
        last;
    };
    /^nspr$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P NSPR $STDERRTOSTDOUT`;
        last;
    };
    /^l10n-mozilla(1\.9.*)$/ && do {
        my $ver = $1;
        my @dirs = <$src_dir/*>;
        unless (scalar @dirs) {
            my $base = 'l10n-central';
            my $orig = $Conf->{'treehash'}{$base};
            @dirs = hg_get_list("http://hg.mozilla.org/releases/l10n-mozilla-$ver");
            foreach my $dir (@dirs) {
                hg_clone_cheap($ver, "l10n-mozilla-$ver", $base, $src_dir, "/" . basename $dir);
            }
            @dirs = <$src_dir/*>;
        }
        foreach my $dir (@dirs) {
            print LOG `cd $dir; $TIME $HGCOMMAND $HGUPDATE $STDERRTOSTDOUT`;
        }
        last;
    };
    /^mozilla(1\.9.*)$/ && do {
        my $ver = $1;
        unless (-d "$src_dir/.hg") {
            hg_clone_cheap($ver, "mozilla-$ver", 'mozilla-central', $src_dir, '');
        }
        print LOG `cd $src_dir; $TIME $HGCOMMAND $HGUPDATE $STDERRTOSTDOUT`;
        last;
    };
    /^(?:seamonkey|(?:aviary(?:101)?|reflow)branch|mozilla1.*)$/ && do {
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=all $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        print LOG `cd mozilla; $TIME $CVSCOMMAND $CVSUP-d tools` if /^seamonkey$/;
        last;
    };
    /^comm-central$/ && do {
        print LOG `cd $src_dir; $TIME python2.4 ./client.py checkout $STDERRTOSTDOUT`;
        last;
    };
    /^(?:.*)-(?:central|tracing)$/ && do {
        print LOG `cd $src_dir; $TIME $HGCOMMAND $HGUPDATE $STDERRTOSTDOUT`;
        last;
    };
    /^firefox.*$/ && do {
        unless (-f 'client.mk') {
          print LOG `$TIME $CVSCOMMAND $CVSCO mozilla/client.mk $STDERRTOSTDOUT`;
        }
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=browser $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        last;
    };
    /^thunderbird.*$/ && do {
        unless (-f 'client.mk') {
          print LOG `$TIME $CVSCOMMAND $CVSCO mozilla/client.mk $STDERRTOSTDOUT`;
        }
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=mail $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        last;
    };
    /^(?:.*)-bzr$/ && do {
        unless (`which $BZR`) {
          print LOG `which $BZR 2>&1`;
          close LOG;
          die "can't find $BZR";
        }
        print LOG `cd $src_dir; $TIME $BZR $BZRUPDATE $STDERRTOSTDOUT`;
        last;
    };
    /^(?:(?:bug|mo)zilla.*-.*)$/ && do {
        print LOG `cd $src_dir; $TIME $CVS $CVSQUIETFLAGS -d ':pserver:anonymous\@cvs-mirror.mozilla.org:/www' $CVSUP -dP * $STDERRTOSTDOUT`;
        last;
    };
    /^fuel$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P -d fuel -rFUEL_DEVEL_BRANCH mozilla/browser/fuel $STDERRTOSTDOUT`;
        last;
    };
    /^(?:.*)-all$/ && do {
        print LOG `$TIME $SVNCOMMAND $SVNUP`;
        last;
    };
    /^(?:.*)$/ && <$src_dir/*/CVS> && do {
        print LOG `cd $src_dir; $TIME $CVSCOMMAND $CVSUP-d * $STDERRTOSTDOUT`;
        last;
    };
    warn "unrecognized tree. fixme!";
}

print LOG `$DATE $STDERRTOSTDOUT`;
print LOG `$UPTIME $STDERRTOSTDOUT`;
close LOG;
exit 0;
