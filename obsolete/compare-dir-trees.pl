#!/usr/bin/perl -w
#
# ./compare-dir-trees.pl /first/path /second/path
#
# returns 0 if both paths have the same elements.
# an element is not the same as another element if it is a different kind of
# object (link, directory, file).
# a directory is not the same as another directory if it has different children.
# a link is not the same as another link if the link data is different.
# a normal file is not the same as another file if their contents differ.
#
# returns a non zero value if any of the above do not hold.

my ($left, $right) = @ARGV;
my $verbose = 0;

sub debug {
  return unless $verbose;
  my ($debug) = @_;
  print STDERR $debug . "\n";
}

sub ensure_d {
  my ($dir) = @_;
  return 0 if -d $dir;
  debug "$dir does not exist!";
  exit -2;
}

sub compare_items {
  my ($l, $lf, $r, $rf) = @_;
  if ($lf eq $rf) {
    return ("$l/$lf", "$r/$rf");
  }
  debug "directory contents mismatch for $l - $r: $lf - $rf";
  exit 1;
}

sub compare_dirs {
  my ($l, $r) = @_;
  my ($l_fail, $r_fail) = (0, 0);
  $l_fail = 1 unless opendir(LEFT, $l);
  $r_fail = 1 unless opendir(RIGHT, $r);
  unless ($l_fail == $r_fail) {
    debug "$l-$l_fail did not match $r-$r_fail!";
    exit 1;
  }
  return if $l_fail;
  my (@llinks, @rlinks, @ldirs, @rdirs, @lfiles, @rfiles);
  {
    my @names = sort readdir(LEFT);
    foreach my $i (@names) {
      next if $i eq '.';
      next if $i eq '..';
      if (-l "$l/$i") {
        push @llinks, $i;
      } elsif (-d "$l/$i") {
        push @ldirs, $i;
      } else {
        push @lfiles, $i
      }
    }
    closedir LEFT;
  }
  {
    my @names = sort readdir(RIGHT);
    foreach my $i (@names) {
      next if $i eq '.';
      next if $i eq '..';
      if (-l "$r/$i") {
        push @rlinks, $i;
      } elsif (-d "$r/$i") {
        push @rdirs, $i;
      } else {
        push @rfiles, $i
      }
    }
    closedir RIGHT;
  }
  my ($lc, $rc) = (scalar @llinks, scalar @rlinks);
  unless ($lc == $rc) {
    debug "link count mismatch $l / $r";
    exit 1;
  }
  {
    for (my $i = 0; $i < $lc; ++$i) {
      my ($lfile, $rfile) = compare_items($l, $llinks[$i], $r, $rlinks[$i]);
      $llink = readlink $lfile;
      $rlink = readlink $rfile;
      if ($llink ne $rlink) {
        debug "$lfile($llink) does not match $rfile($rlink)";
        exit 1;
      }
    }
  }
  ($lc, $rc) = (scalar @lfiles, scalar @rfiles);
  unless ($lc == $rc) {
    debug "file count mismatch $l / $r";
    exit 1;
  }
  {
    for (my $i = 0; $i < $lc; ++$i) {
      my ($lfile, $rfile) = compare_items($l, $lfiles[$i], $r, $rfiles[$i]);
      system('cmp', '-s', $lfile, $rfile);
      if ($? == -1) {
        debug "failed to execute: $!";
        exit 1;
      }
      if ($? & 127) {
        debug "cmp died!";
        exit 1;
      }
      if ($? >> 8) {
        debug "$lfile does not match $rfile";
        exit 1;
      }
    }
  }
  ($lc, $rc) = (scalar @ldirs, scalar @rdirs);
  unless ($lc == $rc) {
    debug "dir count mismatch $l / $r";
    exit 1;
  }
  {
    for (my $i = 0; $i < $lc; ++$i) {
      my ($lfile, $rfile) = compare_items($l, $ldirs[$i], $r, $rdirs[$i]);
      compare_dirs($lfile, $rfile);
    }
  }
}

sub main {
  debug qq!Comparing: "$left" "$right"
!;

  if ($left eq $right) {
    debug "paths are actually the same!";
    exit 0;
  }

  ensure_d($left);
  ensure_d($right);
  compare_dirs($left, $right);
  exit 0;
}

main();
