#!/usr/bin/perl
# $Id: find,v 1.9 2006/12/07 04:59:38 reed%reedloden.com Exp $

# find   --     Find files
#
#       Arne Georg Gleditsch <argggh@ifi.uio.no>
#       Per Kristian Gjermshus <pergj@ifi.uio.no>
#
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

######################################################################

use lib 'lib';
use LXR::Common;
use LXR::Config;

my $hint;
my $lineno;
my @args;

sub find {
    print '
<p class=desc>
Search for files (by name) using <a
href="search-help.html">regular expressions</a>.
</p>
';
    if ($Conf->{'treename'} ne '') {
        print &bigexpandtemplate('<script src="/media/scripts/script.js"></script>');
    }
    print '<form name=find id=find method=get action="find" class="beforecontent">
';
    my @extras = qw(rev mark);
    foreach $extra (@extras) {
        if (defined $HTTP->{'param'}->{$extra} &&
            $HTTP->{'param'}->{$extra} =~ /^([-0-9a-f,.]+)$/i) {
            print qq{<input id="$extra" name="$extra" value="$1" type="hidden">
};
            push @args, ("$extra=$1");
        }
    }

    foreach ($Conf->allvariables) {
        if ($Conf->variable($_) ne $Conf->vardefault($_)) {
            print '<input type=hidden name="' . $_ . '" '.
                  'value="' . $Conf->variable($_) . '">
';
        }
    }

    $searchtext = cleanquery $searchtext;
    $lineno = $HTTP->{'param'}->{'line'};
    $lineno =~ s/\D+//g;
    $hint = clean_hint $hint;

    print qq{
<b><label for="string">Find file:</label></b>
<input type=text id="string" name="string"
value="$searchtext" size=50>};
    if ($Conf->{'treename'} ne '') {
        print ' <label for="tree">in</label>
<select name=tree id=tree onchange="changetarget()">';
      my @treelist = @{$Conf->{'trees'}};
      foreach my $othertree (@treelist) {
        my $default=$othertree eq $Conf->{'treename'} ? ' selected=1' : '';
        print "
<option$default value='$othertree'>$othertree</option>";
      }
    print '
</select>
';
    }
print qq{<input type=submit value="search"><br>
<b><label for="hint" title="each matching path is favored,
only files with the most matches will be shown">Directory hints</label></b>:
<input id="hint" name="hint" value="$hint">
</form>
};
print "<br>";

    if ($searchtext ne "") {
        my $filename = $Conf->dbdir."/.glimpse_filenames";
        unless (open(FILELLISTING, $filename)) {
            &warning("Could not open $filename", 'searchfile');
            return;
        }
        print "<p><hr>\n";

        $searchtext =~ s/\+/\\+/g;

        if ($searchtext =~ /^(\s*)(.*?)(\s*)$/ &&
            (($1 ne '') || ($3 ne ''))) {
            my $find = cleanquery $2;
            print qq%<p><i>Your search included <u>spaces</u></i>,
if this was not your <b>intent</b>,
<i>you can always search <a href="find?string=$find">without them</a>.</i></p>%;
        }
        print qq%<p><i>If you can't find what you're looking for, you can always
<a href="search?string=$searchtext&regexp=on">search</a> for it.</i></p>%;
        $sourceroot = $Conf->sourceroot;
        $file = <FILELLISTING>;
        if ($file !~ /^\d+$/) {
            &warning("glimpse file format doesn't match expectations.", 'glimpsedb');
            return;
        }
        my $highscore = 0;
        my @matches = ();
        my @hints = ();

        if ($hint ne '') {
            $hint =~ s/\./\\./g;
            $hint =~ s/\|/\\b\|\\b/g;
            $hint = "\\b$hint\\b";
            @hints = sort {length $b <=> length $a} (split /\|/, $hint);
        }

        while ($file = <FILELLISTING>) {
            $file =~ s/^$sourceroot//;
            if ($file =~ /$searchtext/i) {
                my $filepath='';
                $filename = $file;
                my $score = 0;
                for $hint (@hints) {
                    ++$score if ($filename =~ s/$hint//);
                }
                ($file, $filename) = split m|/(?!.*/)|, $file;
                print "<span class='s$score'>";
                if (length $file) {
                    foreach my $filepart (split m|/|, $file) {
                        $filepath .= "$filepart/";
                        print &fileref($filepart ? $filepart : '/', "$filepath").
                              ($filepart && '/');
                    }
                } else {
                    $filepath = '/';
                    print &fileref('/', "/");
                }
                $filepath.=$filename;
                push @args, "force=1" if ($filename =~ /\.html?$/);
                push @args, $markstring if $markstring ne '';
                print &fileref("$filename", "$filepath", "$lineno", @args) .
                      '<br>
';

                print "</span>";
                if ($score > $highscore) {
                    my @classes = ();
                    for (; $highscore < $score; ++$highscore) {
                        push @classes, ".s$highscore";
                    }
                    local $, = ", ";
                    print "<style>";
                    print @classes;
                    print "{ display:none }</style>";
                }
            }
        }
    }
}


($Conf, $HTTP, $Path, $head) = &init;
my $searchtext2 = $HTTP->{'param'}->{'text'};
$searchtext = $HTTP->{'param'}->{'string'};
my $tree = $HTTP->{'param'}->{'tree'};
$hint = $HTTP->{'param'}->{'hint'} || '';
my $verb = 'find';
my $refresh;
my $extra;
if ($searchtext2 ne '') {
    if (defined $HTTP->{'param'}->{'i'} || $HTTP->{'param'}->{'kind'} eq 'ident') {
        $verb = 'ident';
        $searchtext2 =~ s/\+//g;
        $searchtext2 =~ s/\s+//g;
        $extra = 'i=' . url_quote($searchtext2);
        $extra .= '&filter=' . url_quote($searchtext) if $searchtext;
    } else {
        $verb = 'search';
        $extra = 'string=' . url_quote($searchtext2);
        $extra .= '&find=' . url_quote($searchtext) if $searchtext;
        $extra .= '&regexp=1' if $HTTP->{'param'}->{'kind'} eq 'regexp';
    }
}
if ($verb ne 'find' || ($tree && ($tree ne $Conf->{'treename'}))) {
    my @treelist = @{$Conf->{'trees'}};
    my $foundtree;
    foreach my $othertree (@treelist) {
        next unless $othertree eq $tree;
        $foundtree = $othertree;
        last;
    }
    $foundtree ||= $Conf->{'treename'} if $verb ne 'find';
    if ($foundtree) {
        my @tail = ();
        if ($extra) {
            push @tail, $extra;
        } else {
            push @tail, "string=" . url_quote($searchtext) if $searchtext ne '';
        }
        push @tail, "hint=" . url_quote($hint) if $hint ne '';
        my $tail = $#tail >= 0 ? '?' . join "&", @tail : '';
        $refresh .= "Refresh: 0; url=../$foundtree/$verb$tail
";
    }
}

print "$head$refresh
";
exit if $refresh ne '';

&makeheader('find');
&find;
&makefooter('find');

1;
