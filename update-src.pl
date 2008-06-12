#!/usr/bin/perl -w
# Run this from cron to update the source tree that lxr sees.
# Created 12-Jun-98 by jwz.
# Updated 27-Feb-99 by endico. Added multiple tree support.
my $skip_lxr_update = 1;
my $CVSROOT=':pserver:anonymous@cvs-mirror.mozilla.org:/cvsroot';

$ENV{PATH}='/opt/local/bin:/opt/cvs-tools/bin:'.$ENV{PATH};

my $TIME = 'time ';
my $UPTIME = 'uptime ';
my $DATE = 'date ';
my $STDERRTOSTDOUT = '2>&1';

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
my $HGUPDATE = 'pull -u ';
my $EACHONE = 'xargs -n1 ';

my $TREE;
my $was_arg;
do {
$was_arg = 0;
$TREE=shift;
if ($TREE) {
if ($TREE eq '-cron') {
$was_arg = 1;
 $TIME = $UPTIME = '';
}
$TREE =~ s{/$}{};
}
} while ($TREE && $was_arg);

my $lxr_dir='.';
open LXRCONF, '<', "$lxr_dir/lxr.conf" || die "can't open lxr.conf";
my $db_dir;
my %sourceroot = ();
do { 
$line = <LXRCONF>;
$db_dir = "$1" if $line =~ /^dbdir:\s*(.*)$/;
$sourceroot{$1} = $2 if $line =~ /^sourceroot:\s*(\S+ |)(.*)/;
} until eof LXRCONF;
die "could not find dbdir: directive"  unless defined $db_dir;
$db_dir .= "/$TREE" if defined $TREE && $TREE ne '';

my $src_dir = $sourceroot{$TREE ? "$TREE " : ''};
die "could not find matching sourceroot" .($TREE ? " for $TREE" :'') unless defined $src_dir;

    #since no tree is defined, assume sourceroot is defined the old way 
    #grab sourceroot from config file indexing only a single tree where
    #format is "sourceroot: dirname"

    #grab sourceroot from config file indexing multiple trees where
    #format is "sourceroot: treename dirname"

my $log="$db_dir/cvs.log";

open LOG, '>', $log;
#print LOG `set -x`;
print LOG `date`;

# update the lxr sources
print LOG `pwd`;
print LOG `$TIME $CVSCOMMAND -d $CVSROOT update -dP` unless $skip_lxr_update;

print LOG `date`;

# then update the Mozilla sources
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
    /^bugzilla(\d.*|)$/ && do {
        chdir '../..';
        print LOG `$TIME $CVSCOMMAND $CVSCO -P mozilla/webtools/bugzilla $STDERRTOSTDOUT`;
        last;
    };
    /^(l10n|l10n-(?:mozilla1\.8|aviarybranch|mozilla1\.8\.0))$/ && do {
        print LOG `$TIME $CVS $CVSQUIETFLAGS -d ':pserver:anonymous\@cvs-mirror.mozilla.org:/l10n' $CVSUP -dP $STDERRTOSTDOUT`;
        last;
    };
    /^mailnews$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P SeaMonkeyMailNews $STDERRTOSTDOUT`;
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
    /^nspr$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P NSPR $STDERRTOSTDOUT`;
        last;
    };
    /^(?:seamonkey|(?:aviary(?:101)?|reflow)branch|mozilla1.*)$/ && do {
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=all $STDERRTOSTDOUT`;
        print LOG `cat cvsco.log $STDERRTOSTDOUT`;
        print LOG `cd mozilla; $TIME $CVSCOMMAND $CVSUP-d tools` if /^seamonkey$/;
        last;
    };
    /^(?:.*)-(central|tracing)$/ && do {
        print LOG `cd $src_dir; $TIME $HGCOMMAND $HGUPDATE $STDERRTOSTDOUT`;
        last;
    };
    /^firefox.*$/ && do {
        print LOG `$TIME make -C mozilla -f client.mk pull_all MOZ_CO_PROJECT=browser $STDERRTOSTDOUT`;
        last;
    };
    /^(?:(?:bug|mo)zilla.*-.*)$/ && do {
        print LOG `cd $src_dir; $TIME $CVSCOMMAND $CVSUP-d * $STDERRTOSTDOUT`;
        last;
    };
    /^fuel$/ && do {
        print LOG `$TIME $CVSCOMMAND $CVSCO -P -d fuel -rFUEL_DEVEL_BRANCH mozilla/browser/fuel $STDERRTOSTDOUT`;
        last;
    };
    warn "unrecognized tree. fixme!";
}

print LOG `$DATE $STDERRTOSTDOUT`;
print LOG `$UPTIME $STDERRTOSTDOUT`;
close LOG;
exit 0;
