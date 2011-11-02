#!/usr/bin/perl
# update-root-xref.pl -- Fixes genxref's paths in case the internal paths change
#
# License: standard mozilla mpl-tri
# orginal author: timeless

######################################################################

use lib 'lib';
use integer;
use DB_File;
use strict;
use Cwd;

my (%fileidx_in, %fileidx);

my ($realpath, $oldpath, $newpath) = ($ARGV[0], $ARGV[1], $ARGV[2]);
$realpath ||= '.';
$realpath .= '/';
$newpath = '' if $newpath eq "''";

sub rewrite {
    my $start = time;
    my $fnum = scalar keys %fileidx_in;
    my $f;


    for (my $curfnum = 1; $curfnum <= $fnum; ++$curfnum) {
        $f = $fileidx_in{$curfnum};
        $f =~ s{$oldpath}{$newpath};
        $fileidx{$curfnum} = $f;
    }

    print(STDERR
          "Completed rewrite ".$fnum." file entries updated.\n\n");
}

chdir($realpath);
tie (%fileidx_in, "DB_File", "fileidx", O_RDONLY, 0660, $DB_HASH)
    || die('Could not open "fileidx" for reading');
tie (%fileidx, "DB_File", "fileidx.out.$$", O_RDWR|O_CREAT, 0660, $DB_HASH)
    || die("Could not open \"fileidx.out.$$\" for writing");


print(STDERR "Rewriting index in $realpath.\n");
chdir($realpath);

rewrite($oldpath, $newpath);

dbmclose(%fileidx);
dbmclose(%fileidx_in);

rename("fileidx.out.$$", "fileidx")
    || die "Couldn't rename fileidx.out.$$ to fileidx";
