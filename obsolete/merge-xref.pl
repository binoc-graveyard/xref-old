#!/usr/bin/perl

use lib 'lib';
use integer;
use DB_File;
use strict;
use LXR::Common;
use LXR::Config;
use File::Basename;

my ($tree, @others) = @ARGV;
# this deals with an implementation detail of LXR::*::init;
$ENV{'SCRIPT_NAME'} = '/' . $tree . '/' . basename($0);
my ($Conf, $HTTP, $Path, $head) = &init($0);

my %treemap = %{$Conf->{'treehash'}};
die "Could not find target $tree" unless defined $treemap{$tree};

my ($dbdir, @trees);
$dbdir = (dirname $Conf->dbdir) . '/';
foreach my $othertree (@others) {
  unless (defined $treemap{$othertree}) {
    print "could not find $othertree\n";
    next;
  }
  push @trees, $othertree;
}

print "Merging: ";
{
  local $, = ', ';
  print @trees;
}
print " into $tree\n";

my (%index, %filelist, %index_in, %filelist_in, $fileno);
my $hash_params = new DB_File::HASHINFO;
$hash_params->{'cachesize'} = 30000;

$fileno = 0;

sub merge_tree
{
  my ($tree, $treedir, $treesrcdir) = @_;
  my $treebase = $tree.'/';
  return unless (
    tie(%index_in,
         "DB_File",
         $treedir."/xref",
         O_RDONLY,
         0664,
         $hash_params)
  );
  unless (
    tie(%filelist_in,
        "DB_File",
        $treedir."/fileidx",
        O_RDONLY,
        undef,
        $hash_params)
  ) {
    untie %index_in;
    return;
  }
  my @filelisting = keys %filelist_in;
  foreach my $key (@filelisting) {
    $filelist{$fileno + $key} = $treebase . $filelist_in{$key};
  }
  untie(%filelist_in);
  foreach my $key (keys %index_in) {
    my $val = $index_in{$key};
    my @ids = split /\t/, $val;
    $val = '';
    foreach my $ref (@ids) {
      if ($ref =~ /^(.)(\d+)(:[0-9,]+)/) {
        $val .= $1 . ($fileno + $2) . "$3\t";
      }
    }
    $index{$key} .= $val;
  }
  $fileno += scalar @filelisting;
  untie(%index_in);
  symlink($treesrcdir, $Conf->sourceroot.'/'.$tree);
}

# dumpdb should move...
sub dumpdb {
  my ($file, $dbref, $statusmsg, $modulus) = @_;
  my %indb = %{$dbref};
  my %outdb;
  tie (%outdb, 'DB_File', $file, O_RDWR|O_CREAT, 0664, $DB_HASH)
      || die("Could not open '$file' for writing");

  my ($i, $k, $v) = (0);
  while (($k, $v) = each(%indb)) {
    $i++;
    delete($indb{$k});
    $outdb{$k} = $v;
    unless (!$modulus || ($i % $modulus)) {
      printf STDERR $statusmsg, $i, $k, $v;
    }
  }

  untie(%outdb);
}

my $fileidxname = $Conf->dbdir . "/fileidx.out.$$";
tie (%filelist, 'DB_File', $fileidxname, O_RDWR|O_CREAT, 0660, $DB_HASH)
    || die("Could not open '$fileidxname' for writing");

foreach $tree (@trees) {
  merge_tree($tree, $dbdir.$tree, $treemap{$tree});
}

$dbdir = $Conf->dbdir;
my $xreffilename = "$dbdir/xref.out.$$";
dumpdb($xreffilename, \%index, 'Dumping identifier %d [%s => %s] to '.$xreffilename."\n", 1);
dbmclose(%filelist);
rename($fileidxname, $dbdir . '/fileidx');
rename($xreffilename, $dbdir . '/xref');
