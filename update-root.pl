#!/usr/bin/perl -w 

use Cwd;
use File::Basename;
use strict;
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

my $STDERRTOSTDOUT = '2>&1';

my ($TREE, $new_src_dir, $force) = @ARGV;
$force = 0 unless defined $force;

die "must specify a tree" unless $TREE ne '';
die "must specify new source directory" unless $new_src_dir ne '';

unless (-d $new_src_dir) {
  die "new src dir $new_src_dir does not exist";
}

$ENV{'LANG'} = 'C';
$TREE =~ s{/$}{};

my $lxr_dir = '.';
my $lxr_conf = "$lxr_dir/lxr.conf";
unless (-f $lxr_conf) {
  die "could not find $lxr_conf";
}

# let LXR:: handle lxr.conf
$ENV{'SCRIPT_NAME'} = "/$TREE/" . basename($0);
my ($Conf, $HTTP, $Path, $head) = &init($0);

my $db_dir = dirname $Conf->dbdir;
my $src_dir = $Conf->sourceroot;

unless (-d $db_dir) {
  die "dbdir: $db_dir does not exist, did you just move the whole lxr?";
}
$db_dir = $Conf->dbdir;

open LXRCONF, "< $lxr_conf" || die "Could not open $lxr_conf";
my $newconf = '';
my $line;
while ($line = <LXRCONF>) {
  warn "trailing whitespace on line $. {$line}" if $line =~ /^\w+:.*\w.* \s*$/;

  #grab sourceroot from config file indexing multiple trees where
  #format is "sourceroot: treename dirname"
  if ($line =~ /^sourceroot:\s*\Q$TREE\E\s+(\S+)$/) {
    $src_dir = $1;
    $line = "sourceroot: $TREE $new_src_dir\n"; 
  }
  $newconf .= $line;
}
close LXRCONF;

push @paths, $1 if ($Conf->glimpsebin =~ m{(.*)/([^/]*)$});

unless (defined $src_dir) {
  die "could not find sourceroot for tree $TREE";
}

open LXRCONF2, "> $lxr_conf.new";
print LXRCONF2 $newconf;
close LXRCONF2;

my %pathmap=();
for my $mapitem (@paths) {
  $pathmap{$mapitem} = 1;
}
for my $possible_path (keys %pathmap) {
  $ENV{'PATH'} = "$possible_path:$ENV{'PATH'}" if -d $possible_path;
}

unless (-d $db_dir) {
  die "could not find database for tree $TREE";
} else {
  my $file_index = $db_dir . '/.glimpse_filenames';
  unless (-f $file_index) {
    unless ($force) {
      die "could not find file index for tree $TREE";
    }
    warn "tree $TREE did not have an index";
  } else {
    my $changed = 0;
    open FILELIST, "< $file_index";
    open NEWFILELIST, "> $file_index.new";
    while ($line = <FILELIST>) {
      $changed = 1 if $line =~ s/\Q$src_dir\E/$new_src_dir/;
      print NEWFILELIST $line;
    }
    close NEWFILELIST;
    close FILELIST;

    if ($changed) {
      rename "$file_index.new", $file_index;

      my $cmd = "(glimpseindex -R -H $db_dir $STDERRTOSTDOUT)";
      print "$cmd
";
      system($cmd);

      # build filename index
      # shared w/ update-search.pl
      my $db_dir_tmp = "$db_dir/tmp";
      mkdir $db_dir_tmp;
      my $mxr_dir_tmp = "$db_dir_tmp/.mxr";
      mkdir $mxr_dir_tmp;

      $cmd = "cp $db_dir/.glimpse_filenames $mxr_dir_tmp/files
(glimpseindex -H $mxr_dir_tmp $mxr_dir_tmp $STDERRTOSTDOUT)
perl -pi -e 's{tmp/\.mxr}{\.mxr}' $mxr_dir_tmp/.glimpse_filenames
glimpseindex -H $mxr_dir_tmp -R
";
      if (-d "$db_dir/.mxr") {
        $cmd .= "mv $db_dir/.mxr $db_dir/.mxr-0
mv $mxr_dir_tmp $db_dir/.mxr
rmdir $db_dir_tmp 
rm -rf $db_dir/.mxr-0";
      } else {
        $cmd .= "mv $mxr_dir_tmp $db_dir/.mxr";
      }
      system($cmd);
    } else {
      unlink "$file_index.new";
      print "no changes needed\n";
    }
  }
}
rename "$lxr_conf.new", $lxr_conf;

exit 0;
