#!/usr/bin/perl -w
# Run this from cron to update the source tree that lxr sees.
# Created 12-Jun-98 by jwz.
# Updated 27-Feb-99 by endico. Added multiple tree support.

use Cwd;
use File::Basename;
use List::MoreUtils qw(uniq);
use lib 'lib';
use LXR::Common;
use LXR::Config;
use LXR::Shell;

my @paths=qw(
/usr/local/bin
);

my $CVSROOT=':pserver:anonymous@cvs-mirror.mozilla.org:/cvsroot';

$ENV{PATH}='/usr/local/bin:'.$ENV{PATH};

my ($lxr_dir, $lxr_conf, $db_dir, $src_dir, $Conf, $HTTP, $Path, $head);

my $STDERRTOSTDOUT = '2>&1';
my $STDERRTODEVNUL = '2>/dev/null';
my $ERROR_OUTPUT = $STDERRTOSTDOUT;

my $TIME;
my $UPTIME;
my $DATE;

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

my $HGCOMMAND = 'timeout 1h hg ';
my $HGCLONE = 'clone ';
my $HGUP = 'up ';
my $HGCHANGESET = 'parents --template="{node|short}\n"';

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
          "[ -d $destextra ] && rmdir $destextra $STDERRTOSTDOUT; cd $orig;".
          "$TIME ($HGCOMMAND $HGCLONE .#$tag $destextra || $HGCOMMAND $HGCLONE . $destextra) $STDERRTOSTDOUT;".
          "cd $destextra;".
          "perl -pi -e 's!default =.*!default = http://hg.mozilla.org/releases/$prefixextra!' .hg/hgrc;".
          "$TIME $HGCOMMAND $HGUP $STDERRTOSTDOUT;";
        print LOG $command;
        print LOG `$command`;
    }
    unless (-d "$destextra/.hg") {
        my $src = basename($dest);
        print LOG `cd $src; $TIME $HGCOMMAND $HGCLONE http://hg.mozilla.org/releases/$prefixextra $STDERRTOSTDOUT`;
    }
}

sub hg_update {
    my ($dir, $branch, $origin) = @_;
    # If no branch argument is specified, 'default' is used
    $branch = 'default' unless defined $branch;
    # Unless empty is specified, we specify the branch (either default
    # or the one which was passed as branch).
    $branch = "-r $branch" if $branch;
    $origin = 'default' unless defined $origin;
    # $origin isn't used yet.
    print LOG `cd $dir; $TIME $HGCOMMAND pull $branch $STDERRTOSTDOUT || pwd; $HGCOMMAND update --clean $STDERRTOSTDOUT; $HGCOMMAND $HGCHANGESET`;
}


my $EACHONE = 'xargs -n1 ';

my $BZR = 'bzr ';
my $BZRQUIETFLAGS = '-q ';
my $BZRUPDATE = 'update $BZRQUIETFLAGS';

my $TREE;
my %defaults = qw(
  TIME time
  UPTIME uptime
  DATE date
);

sub process_args {
  my $was_arg;
  do {
    $was_arg = 0;
    $TREE = shift;
    if ($TREE) {
      if ($TREE eq '-cron') {
        $was_arg = 1;
        $defaults{TIME} = $defaults{UPTIME} = '';
        $ERROR_OUTPUT = $STDERRTODEVNUL;
      }
      $TREE =~ s{/$}{};
    }
  } while ($TREE && $was_arg);
}

process_args(@ARGV);

check_defaults(\%defaults);
$DATE = $defaults{DATE};
$TIME = $defaults{TIME};
$UPTIME = $defaults{UPTIME};

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
  if (defined $TREE) {
    $db_dir .= "/$TREE" if $TREE ne '';
  } else {
    $TREE = '';
  }
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
my $pid_lock = get_lock($db_dir, 'src');
my $log="$db_dir/cvs.log";

rename $log, "$log.old" if -f $log;
open LOG, '>', $log || die "can't open $log";
#print LOG `set -x`;
print LOG `date`;
print LOG `pwd`;

# then update the Mozilla sources
-d $src_dir || mkdir $src_dir;
chdir dirname $src_dir;

# endico: check out the source
for ($TREE) {
    /^$/ && do {
        warn "You need to fill in your update script here. fixme!";
        last;
    };
    /^world-all$/ && do {
        print LOG `$TIME (echo */* | $EACHONE $SVNCOMMAND $SVNUP)`;
        last;
    };
    /^classic$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P -rMozillaSourceClassic_19981026_BRANCH MozillaSource $STDERRTOSTDOUT`;
        last;
    };
    /^chromium$/ && do {
        # http://dev.chromium.org/developers/how-tos/get-the-code
        # must have the depot-tools installed already
        # check for depot-tools, install if necessary
        if (-d "$src_dir/../depot_tools") {
            # update_depot_tools won't run as root; easier to run a 
            # sed one-liner than natively. it will also complain if
            # you modify in-place and run
            chdir "$src_dir/../depot_tools";
            print LOG `sed -e '1!N; s/^.*Running depot tools as root is sad\\.\\n.*exit/  echo Running depot tools as root/' < update_depot_tools > update_depot_tools.root`;
            chmod 0755, "update_depot_tools.root";
            print LOG `./update_depot_tools.root`;
        } else {
            chdir "$src_dir/..";
            print LOG `git clone https://git.chromium.org/chromium/tools/depot_tools.git`;
	}
        chdir $src_dir;
        unless (-f "$src_dir/.gclient") {
            print "\nBREAK: check out manually by running the following in $src_dir:\n";
            print "../depot_tools/gclient config https://src.chromium.org/chrome/trunk/src https://chromium-status.appspot.com/lkgr\n";
            print "Then edit $src_dir/.gclient, per http://dev.chromium.org/developers/how-tos/get-the-code#TOC-Reducing-the-size-of-your-checkout\n";
            print "Not attempting to do this automatically... quitting here!\n\n";
            last;
        }
        print LOG `../depot_tools/gclient sync`;
        last;
    };
    /^gaia$/ && do {
        if (! -d "$src_dir/.git") {
            print LOG `git clone https://github.com/mozilla-b2g/gaia $src_dir $STDERRTOSTDOUT`;
        } else {
            chdir $src_dir;
            print LOG `git pull $STDERRTOSTDOUT`;
            print LOG `git gc $STDERRTOSTDOUT`;
        }
        last;
    };
    /^(rust|servo)$/ && do {
        my $repo = $1;
        if (! -d "$src_dir/.git") {
            print LOG `git clone https://github.com/mozilla/$repo $src_dir $STDERRTOSTDOUT`;
        } else {
            chdir $src_dir;
            print LOG `git pull $STDERRTOSTDOUT`;
            print LOG `git gc $STDERRTOSTDOUT`;
        }
        last;
    };
    /^js$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P mozilla/js mozilla/js2 mozilla/nsprpub $STDERRTOSTDOUT`;
        last;
    };
    /^security$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P mozilla/security mozilla/nsprpub mozilla/dbm $STDERRTOSTDOUT`;
        last;
    };
    /^webtools$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P mozilla/webtools $STDERRTOSTDOUT`;
        last;
    };
    /^bugzilla(\d.*|)$/ && do {
        my $ver = $1;
        my $dir = basename($src_dir);
        unless (-d "$src_dir/CVS") {
          chdir dirname $src_dir;
          if ($ver) {
            $ver =~ s/\.x//;
            $ver =~ s/\./_/g;
            $ver = "-r BUGZILLA-$ver-BRANCH";
          }
          print LOG `$TIME $CVSCOMMAND $CVSCO -P $ver -d $dir mozilla/webtools/bugzilla $STDERRTOSTDOUT`;
        } else {
          print LOG `$TIME $CVSCOMMAND $CVSUP -P -d $dir $STDERRTOSTDOUT`;
        }
        last;
    };
    /^(?:l10n|l10n-(?:mozilla1\.8|aviarybranch|mozilla1\.8\.0))$/ && do {
        print LOG `$TIME $CVS $CVSQUIETFLAGS -d ':pserver:anonymous\@cvs-mirror.mozilla.org:/l10n' $CVSUP -dP $STDERRTOSTDOUT`;
        last;
    };
    /^mobile-browser$/ && do {
        hg_update($src_dir);
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
            hg_update($dir);
        }
        last;
    };
    /^(?:(build|incubator|l10n|labs|projects|services|webtools)-central|(l10n)-(mozilla-\D.*))$/ && do {
        my @dirs = <$src_dir/*>;
        my $fallback = defined $1 ? $1 : "releases/$2/$3";
        $fallback .= '-central' if $fallback eq 'l10n';
        $fallback = "http://hg.mozilla.org/$fallback";
        my $general_root;
        foreach my $dir (@dirs) {
            if ( -d $dir ) {
                unless (defined $general_root) {
                    $general_root = `hg paths default -R $dir`;
                    $general_root =~ s{/[^/]+/?\s*$}{};
                }
                hg_update($dir);
            }
        }
        $general_root = $fallback unless defined $general_root;
        chdir $src_dir;
        @dirs = hg_get_list($general_root);
        foreach my $dir (@dirs) {
            unless (-d $dir) {
                print LOG `$TIME $HGCOMMAND $HGCLONE $general_root/$dir $STDERRTOSTDOUT`;
            }
        }
        last;
    };
    /^(.*\.gitorious\.org)$/ && do {
        pull_gitorious($1);
        last;
    };
    /^nspr-cvs$/ && do {
	# Seems wrong, per bug 730010
        # print LOG `$TIME $CVSCOMMAND $CVSCO -P NSPR $STDERRTOSTDOUT`;
	print LOG `$TIME $CVSCOMMAND $CVSCO -P mozilla/nsprpub $STDERRTOSTDOUT`;
        last;
    };
    /^l10n-gaia(-v[\d_]+)?$/ && do {
        my $ver = defined $1 ? "/$1" : '';
        my $rel = defined $1 ? 'releases/' : '';
        $ver =~ s/-//;
        my $url = "http://hg.mozilla.org/${rel}gaia-l10n${ver}";
        my @ldirs = <$src_dir/*>;
        my @rdirs = hg_get_list($url);
        my @dirs = sort uniq(@ldirs, @rdirs);
        foreach my $dir (@dirs) {
            if ( -d $dir ) {
                hg_update($dir);
            } else {
                print LOG `$TIME $HGCOMMAND $HGCLONE $url/$dir $src_dir/$dir $STDERRTOSTDOUT`;
            }
        }
        last;
    };
    /^l10n-mozilla(1\.9.*|2\.0.*)$/ && do {
        my $ver = $1;
        my @dirs;
        {
            my $base = 'l10n-central';
            my $orig = $Conf->{'treehash'}{$base};
            @dirs = hg_get_list("http://hg.mozilla.org/releases/l10n-mozilla-$ver");
            foreach my $dir (@dirs) {
                hg_clone_cheap($ver, "l10n-mozilla-$ver", $base, $src_dir, "/" . basename $dir);
            }
            @dirs = <$src_dir/*>;
        }
        foreach my $dir (@dirs) {
            if ( -d $dir ) {
                hg_update($dir);
            }
        }
        last;
    };
    /^mozilla(1\.9.*|2\.0.*)$/ && do {
        my $ver = $1;
        unless (-d "$src_dir/.hg") {
            hg_clone_cheap($ver, "mozilla-$ver", 'mozilla-central', $src_dir, '');
        }
        hg_update($src_dir);
        last;
    };
    /^mozilla1\.7$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -r MOZILLA_1_7_BRANCH mozilla/client.mk $STDERRTOSTDOUT`;
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=all $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        last;
    }; 
    /^mozilla1\.8$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -r MOZILLA_1_8_BRANCH mozilla/client.mk $STDERRTOSTDOUT`;
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=all $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        last;
    }; 
    /^mozilla1\.8\.0$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -r MOZILLA_1_8_0_BRANCH mozilla/client.mk $STDERRTOSTDOUT`;
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=all $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        last;
    }; 
    /^seamonkey$/ && do {
        # does not pull from a specific branch/tag?
        print LOG `$TIME $CVSCOMMAND $CVSCO mozilla/client.mk $STDERRTOSTDOUT`;
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=all $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        print LOG `cd mozilla; $TIME $CVSCOMMAND $CVSUP-d tools`;
        last;
    };
    /^aviarybranch$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -r AVIARY_1_0_20040515_BRANCH mozilla/client.mk $STDERRTOSTDOUT`;
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=all $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        last;
    }; 
    /^aviary101branch$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -r AVIARY_1_0_1_20050124_BRANCH mozilla/client.mk $STDERRTOSTDOUT`;
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=all $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        last;
    }; 
    /^comm-(?:central|1\.9\.\d+|2\.0|release|aurora|beta|esr10|esr17|esr24)$/ && do {
        print LOG `cd $src_dir; $TIME python ./client.py checkout $STDERRTOSTDOUT`;
        last;
    };
    /^(?:.*-(?:central|tracing)|(mozilla-\D.*))$/ && do {
        if (-d "$src_dir/.hg") {
          hg_update($src_dir);
        } else {
          my $dir = $1 ? "releases/$1" : basename($src_dir);
          print LOG `$TIME $HGCOMMAND $HGCLONE https://hg.mozilla.org/$dir $src_dir`;
        }
        last;
    };
    /^(mozilla-esr10|mozilla-esr17|mozilla-esr24)$/ && do {
        if (-d "$src_dir/.hg") {
          hg_update($src_dir);
        } else {
          my $dir = $1 ? "releases/$1" : basename($src_dir);
          print LOG `$TIME $HGCOMMAND $HGCLONE https://hg.mozilla.org/$dir $src_dir`;
        }
        last;
    };
    /^(mozilla-b2g18|mozilla-b2g26_v1_2|mozilla-b2g28_v1_3)$/ && do {
        if (-d "$src_dir/.hg") {
          hg_update($src_dir);
        } else {
          my $dir = $1 ? "releases/$1" : basename($src_dir);
          print LOG `$TIME $HGCOMMAND $HGCLONE https://hg.mozilla.org/$dir $src_dir`;
        }
        last;
    };
    /^mozmill-tests$/ && do {
        if (-d "$src_dir/.hg") {
          hg_update($src_dir);
        } else {
          print LOG `$TIME $HGCOMMAND $HGCLONE https://hg.mozilla.org/qa/mozmill-tests $src_dir`;
        }
        last;
    };
    /^(nss|jss|nspr)$/ && do {
        if (-d "$src_dir/.hg") {
          hg_update($src_dir);
        } else {
          my $dir = $1 ? "projects/$1" : basename($src_dir);
          print LOG `$TIME $HGCOMMAND $HGCLONE https://hg.mozilla.org/$dir $src_dir`;
        }
        last;
    };
    /^(python-nss)$/ && do {
        if (-d "$src_dir/.hg") {
          hg_update($src_dir);
        } else {
          print LOG `$TIME $HGCOMMAND $HGCLONE https://hg.mozilla.org/projects/python-nss $src_dir`;
        }
        last;
    };
    /^firefox$/ && do {
        unless (-f 'client.mk') {
          print LOG `$TIME $CVSCOMMAND $CVSCO mozilla/client.mk $STDERRTOSTDOUT`;
        }
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=browser $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        last;
    };
    /^firefox2$/ && do {
        unless (-f 'client.mk') {
          print LOG `$TIME $CVSCOMMAND $CVSCO -r MOZILLA_1_8_BRANCH mozilla/client.mk $STDERRTOSTDOUT`;
        }
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=browser $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        last;
    };
    /^camino$/ && do {
        if (-d "$src_dir/.hg") {
          print LOG `cd $src_dir; cd ..; mkdir 0; mv camino 0; mv 0 camino`;
        }
        if (-d "$src_dir/camino/.hg") {
          hg_update("$src_dir/camino");
        } else {
          my $dir = basename($src_dir);
          print LOG `mkdir $src_dir/camino; $TIME $HGCOMMAND $HGCLONE https://hg.mozilla.org/$dir $src_dir/camino`;
        }
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
          print LOG `which $BZR $STDERRTOSTDOUT`;
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
        print LOG `$TIME $SVNCOMMAND $SVNUP $STDERRTOSTDOUT`;
        last;
    };
    /^addons$/ && do {
        print LOG `rm -rf /data/mxr-data/addons/incoming; mkdir /data/mxr-data/addons/incoming`; # should be unnecessary
        print LOG `cd /data/amo-code/bin; $TIME python2.6 -S latest_addon_extractor.py /data/addons /data/mxr-data/addons/incoming`;
	print LOG `mv /data/mxr-data/addons/addons /data/mxr-data/addons/old`;
	print LOG `mv /data/mxr-data/addons/incoming /data/mxr-data/addons/addons`;
	print LOG `mkdir /data/mxr-data/addons/incoming`;
	system("rm -rf /data/mxr-data/addons/old &"); # do this in the background... doesn't need to block other stuff
        last;
    };
    /^addons-stage$/ && do {
        print LOG `cd /data/amo-code/bin; $TIME python2.6 -S latest_addon_extractor.py /data/addons /data/mxr-data/addons-stage/addons`;
        last;
    };
    /^(?:.*)$/ && do {
        my @dirs = <$src_dir/*/CVS>;
        if (scalar @dirs) {
            foreach my $dir (@dirs) {
                $dir =~ s/CVS$//; $dir =~ s{//+}{/}g;
                print LOG `cd $dir; $TIME $CVS $CVSQUIETFLAGS $CVSUP-d $STDERRTOSTDOUT`;
            }
            last;
        }
    };
    warn "unrecognized tree. fixme!";
}

sub get_gitorious_repos {
  my ($root) = @_;
  open GITORIOUS, "curl -s $root|";
  my @repos = ();
  while (<GITORIOUS>) {
    next unless /^git clone/;
    push @repos, $_;
  }
  close GITORIOUS;
  return @repos;
}

sub get_gitorious_roots {
  my ($host) = @_;
  open GITORIOUS_ROOTS, "curl -s $host|";
  my $state = 0;
  while (<GITORIOUS_ROOTS>) {
    if ($state == 0) {
      next unless /site_overview/;
      $state = 1;
    } elsif ($state == 1) {
      if (/id="right"/) {
        $state = 2;
        next;
      }
      next unless m!<strong><a href="(/.*)">!;
      push @repos, "$host$1";
    }
  }
  close GITORIOUS_ROOTS;
  my @git_repos = ();
  foreach my $repo (@repos) {
    push @git_repos, get_gitorious_repos($repo);
  }
  return @git_repos;
}

sub pull_gitorious {
  my ($host) = @_;

  # $src_dir is a global variable
  chdir $src_dir;
  my @dirs = sort <*>;
  foreach my $dir (@dirs) {
    # we pass '' to mean "don't use 'default' with update magic"
    # we could try doing something fancier like master/origin
    hg_update($dir, '');
  }
  $host = "http://$host" unless $host =~ m!://!;
  my @git_cmds = get_gitorious_roots($host);
  foreach my $git_cmd (@git_cmds) {
    $git_cmd =~ /git clone (\S+)\s+(\S+)/;
    $dir = $2;
    my $repo = $1;
    next if -d $dir;
    if (-e $dir) {
      print LOG "Found object $dir while trying to git clone $repo\n";
      next;
    }
    if ($repo !~ m!\w+://(.*$)! ||
        "$1$dir" =~ m![^-+a-z0-9_./]!i) {
      print LOG "Unexpected characters for git clone $repo $dir\n";
      next;
    }
    print LOG `$TIME $HGCOMMAND $HGCLONE '$repo' '$dir' $STDERRTOSTDOUT`;
  }
}

print LOG `$DATE $STDERRTOSTDOUT`;
print LOG `$UPTIME $STDERRTOSTDOUT` if $UPTIME =~ /\w/;
close LOG;
unlink $pid_lock;
exit 0;
