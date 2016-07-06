#!/usr/bin/perl

my $lxr_dir = '.';

if ($#ARGV <= 0) {
print "Syntax: $0 tree path/to/tree [prefix]
";
exit;
}

my ($tree, $path, $prefix);
$tree = $ARGV[0];
$path = $ARGV[1];
$prefix = $ARGV[2] if $#ARGV > 1;

die "invalid tree name" if $tree =~ /[\s:]/;

open LXRCONF, ">> $lxr_dir/lxr.conf";
print LXRCONF "sourceroot: $tree $path
";
if (defined $prefix) {
 print LXRCONF "sourceprefix: $tree $prefix
";
}
chdir($lxr_dir);
symlink('.', $tree);
close LXRCONF;
