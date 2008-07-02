#!/usr/bin/perl -w 

use Cwd;
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

my $TREE = shift;
my $new_src_dir = shift;
die unless $TREE ne '' && $new_src_dir ne '';
unless (-d $new_src_dir) {
  die "new src dir $new_src_dir does not exist";
}

$ENV{'LANG'} = 'C';
$ENV{'TREE'} = $TREE;

$lxr_dir = '.';
my $lxr_conf = "$lxr_dir/lxr.conf";
unless (-f $lxr_conf) {
die "could not find $lxr_conf";
}
open LXRCONF, "< $lxr_conf";
my $newconf = '';
while ($line = <LXRCONF>) {
    $db_dir = "$1/$TREE" if $line =~ /^dbdir:\s*(\S+)/;
    warn "trailing whitespace on line $. {$line}" if $line =~ /^\w+:.*\w.* \s*$/;
    #grab sourceroot from config file indexing multiple trees where
    #format is "sourceroot: treename dirname"
    if ($line =~ /^sourceroot:\s*\Q$TREE\E\s+(\S+)$/) {
        $src_dir = $1;
        $line = "sourceroot: $TREE $new_src_dir\n"; 
    } elsif ($line =~ /^glimpsebin:\s*(.*)\s*$/) {
        $glimpse_bin = $1;
        $glimpse_bin =~ m{(.*)/([^/]*)$};
        push @paths, $1;
    }
    $newconf .= $line;
}
close LXRCONF;

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
}
my $file_index = $db_dir . '/.glimpse_filenames';
unless (-f $file_index) {
die "could not find file index for tree $TREE";
} 


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
} else {
unlink "$file_index.new";
print "no changes needed";
}
rename "$lxr_conf.new", $lxr_conf;

exit 0;
