#!/usr/bin/perl
# $Id: search,v 1.10 2006/12/07 04:59:38 reed%reedloden.com Exp $

# search --  Freetext search
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
use Local;
use LXR::Common;
use LXR::Config;

$maxhits = 3000;

my ($openlist, $lastfilepath, $skip);
my $styles="
<style type='text/css'>";
my $stylee="</style>
";

sub toggle_style
{
  my ($n, $m) = @_;
  my $s=0; my $t=10;
  my @inline = (), @none = ();
  push @none, ".$m$s"."_".(($n-1 % $t) % 10);
  push @inline, ".$m$s"."_".(($n % $t) % 10);
  if (($n % $t) == 0) {
    do {
      $n = ($n / 10) | 0;
      ++$s;
      if ($n % 10 == 0) {
          push @none, ".$m$s"."_9";
          push @inline, ".$m$s"."_0";
      }
    } while ($n>=10 && (($n % 10) == 0));
    push @none, ".$m$s"."_".(($n -1) % 10);
    push @inline, ".$m$s"."_".($n % 10);
  }
  return join(',',@none)."{display:none;}
".join(',',@inline)."{display:inline;}";
}

sub display_line
{
    my ($glimpseline, $re) = @_;
    $sourceroot = $Conf->sourceroot;
    $glimpseline =~ s/$sourceroot//;
    ($file, $line, $text) =
        $glimpseline =~ /(.*?):\s*(\d+)\s*:(.*)/;
    if (length($text) > 160) {
        # the string is way too long
        # "hello cruel world what time is it this day. We are here to \
        #  celebrate the beginning of things which no one cares about \
        #  because it is so very important. When for other reasons it \
        #  becomes clear that no one really cares. We should stop it."
        my $context = '.{0,20}';
        $text =~ s/.*?($context$re$context)/..$1../g;
        $text =~ s/($re$context)((?!$re).)*$/$1.../;
        $text = '.' . $text;
    }

    my $path='';
    my $filename;
    my $skip = $lastfilepath eq $file;
    #$skip = 0;
    $lastfilepath = $file;
    if ($openlist && !$skip) {
        $openlist = 0;
        print ('</ul>');
    }
    ($file,$filename)=split m|/(?!.*/)|, $file;
    foreach my $filepart ($file =~ m{^/?$} ? ('') : split m|/|, $file) {
        $path .= "$filepart/";
        unless ($skip) {
            print(&fileref($filepart ? $filepart : '/', "$path"),
                  $filepart && '/');
        }
    }
    my $filepath = $path ? $path . $filename : "/$filename";
    my @frargs = ();
    if ($filename =~ /\.html?$/) {
        @frargs = ("force=1");
    }
    unless ($skip) {
        print(&fileref("$filename", "$filepath"));
        print(&blamerefs($file.'/'.$filename));
    }
    unless ($skip) {
        print ('<ul>');
        $openlist = 1;
    }
    print ('<li>');
    print(&fileref("line $line", "$filepath", $line, @frargs),
          " -- ".markupstring($text, "$path")."<br>\n");
}

sub escape_re {
    $re = shift;
    $re =~ s/([-.*+?{}|()^\\\[\]`])/\\$1/g;
    return $re;
}

sub escape_comment {
    my $comment = shift;
    $comment =~ s/\&/\&amp;/g;
    $comment =~ s/</\&lt;/g;
    $comment =~ s/>/\&gt;/g;
    $comment =~ s/"/\&quot;/g;
    $comment =~ s/-/\&#45;/g;
    return $comment;
}

sub print_ident_hints
{
    my ($requestedsearch) = @_;
    my @idents = ();
    my @terms = split /[^~a-z_0-9]+/i, $requestedsearch;
    if (scalar @terms) {
        my %list = ();
        foreach my $term (@terms) {
            $list{$term} = 1;
        }
        @terms = keys %list;
        use DB_File;
        my %xref;
        if (tie(%xref, "DB_File", $Conf->dbdir."/xref",
                O_RDONLY, undef, $DB_HASH)) {
            foreach my $term (@terms) {
                if (defined $xref{$term}) {
                    push @idents, '<a href="ident?i='.$term.'&strict=1">'.$term.'</a>';
                }
            }
            if (scalar @idents) {
                print '<p>For faster searches, you could search for these identifiers: '.
                    join(', ', @idents) . '</p>';
            }
            untie(%xref);
        }
    }
}

sub search {
    print(qq{<p class=desc>
Free-text search through the source code, including comments.
<br>By default, this form treats all characters as literals.
<br>Search strings can have a maximum of 29 characters.
<br>Read the <a href="search-help.html">documentation</A>
 for help with glimpse's regular expression syntax,
});
    my $changetarget = '';
    print &bigexpandtemplate('<script src="/media/scripts/script.js"></script>');

    my $note;
    my @filters = ();
    my $displayedsearch = escape_comment($searchtext);
    my $requestedsearch = $searchtext;

    if ($searchtext =~ /\S/) {
        if ($searchtext !~ /[a-zA-Z0-9]/) {
            push @filters, ($regexp ? $searchtext : escape_re($searchtext));
            $searchtext = $search_sensitive ? '[a-zA-Z]' : '[a-z]';
            $regexp = 1;
            $note = "<p><strong>Your search did not contain any indexed characters,
and was converted into a filter.</strong></p>\n";
        } elsif (!$regexp && $searchtext =~ /\s*(.{29}).+?\s*/) {
            push @filters, escape_re($searchtext);
            $searchtext = $1;
            $note = "<p><strong>Your search was too long, the full search was
converted into a filter.</strong></p>\n";
        }
    }

    print('<form name=search id=search method=get action="search" class="beforecontent">');
    my @extras = qw(rev line mark);
    foreach $extra (@extras) {
        if (defined $HTTP->{'param'}->{$extra} &&
            $HTTP->{'param'}->{$extra} =~ /^([-0-9a-f,]+)$/i) {
            print("<input type='hidden' value='$1'>
");
            $args .= "&$extra=$1";
        }
    }

    print('<table><tr><td>');

    foreach ($Conf->allvariables) {
        if ($Conf->variable($_) ne $Conf->vardefault($_)) {
            print('<input type=hidden name="',$_, '" ',
                  'value="', $Conf->variable($_), '">
');
        }
    }

    print('<b>
<label for="string">Search for:</label></b></td>
<td>
<input type=text id="string" name="string"
value="',$displayedsearch,'" size=30>
<input type=submit value="search"><br>
</td></tr><tr><td></td><td>
<input type="checkbox" id="regexp" name="regexp"');
    if ($regexp) {
        print (' checked');
        print (' value="1"');
    }
    print '><label for="regexp">Regular Expression Search</label>
</td><tr><td><td><input type="checkbox" id="case" name="case"';
    if ($search_sensitive) {
        print (' checked');
        print (' value="1"');
    }
    print '><label for="case">Case sensitive</label>
';

my $value = escape_comment($find);
    print('</td>
<tr><td><label for="find">in files matching:</label></td>
<td><input type=text id="find" name="find" value="'.
$value.
'" size=30>');

    if ($find_warning) {
        print ' a suggestion was made by your browser, but it was ignored in favor of the provided string, if you empty the string and search again, it will be honored.';
    }

    print ' <label for="findi">Suggestions from our users:</label>
<select id="findi" name="findi" onchange="changefindpreset()">
<option value="">none of these</option>';
# this needs to move into Local.pm
@find_options = qw(
\.xul$
\.dtd$
\.po$
\.c
\.h$
\..$
\.[chj]
\.x.l
\.idl$
\.css
\.htm
\.xml
\.js
\.rdf
\.in
debian/control
);

$findi = cleanFind($findi);

    foreach my $find_opt (@find_options) {
        my $find_default = ($find_opt eq $findi)
                         ? ' selected="selected"' : '';
        print "<option$find_default value='$find_opt'>$find_opt</option>
";
    }
    print '</select>
';

$value = escape_comment($filter);

    print '</td></tr>
<tr><td><label for="filter">Limit output to pattern:</label></td>
<td><input type=text id="filter" name="filter" value="'.
$value.'" size=30></td></tr>
<tr><td><label for="hitlimit">Limit matches per file to:</label></td>
<td><input type=text id="hitlimit" name="hitlimit" value="'.
$hitlimit.'" size=10>';
    if ($Conf->{'treename'} ne '') {
        print('</td></tr><tr><td>
<label for="tree">using tree:</label></td><td>
<select name="tree" id="tree" onchange="changetarget()">
');
        my @treelist = @{$Conf->{'trees'}};
        foreach my $othertree (@treelist) {
            my $default = $othertree eq $Conf->{'treename'}
                   ? ' selected=1' : '';
            print "<option$default value='$othertree'>$othertree</option>
";
        }
        print '</select>';
    }
    print '</td></tr></table>
</form>

';

    $| = 1; print('');

    if ($isregexp && $searchtext ne "" && $searchtext =~ /[\[\]{}\\]/) {
        my $bracketsearchtext = $searchtext;
        my $doublebackslash = '\\\\';
        $bracketsearchtext =~ s/$doublebackslash$doublebackslash//g;
        $bracketsearchtext =~ s/[^\[\]{}\\]/x/g;
        $bracketsearchtext =~ s/\\[\[\]]/x/g;
        my @brackets = ();
        my $start_or_not_escape = '(?:^|[^\\\\])';
        if (($bracketsearchtext =~ s/$start_or_not_escape\[//g) !=
            ($bracketsearchtext =~ s/$start_or_not_escape\]//g)) {
            push @brackets, qw( [ ] );
        }
        if (($bracketsearchtext =~ s/$start_or_not_escape\{//g) !=
            ($bracketsearchtext =~ s/$start_or_not_escape\}//g)) {
            push @brackets, qw( { } );
        }
        if (scalar @brackets) {
            $searchtext = '';
            print "<em>Can't search with mismatched brackets: ".join(', ', @brackets)."</em><br>
";
        }
    }
    if (! -e $Conf->glimpsebin) {
        &fatal("Search isn't available;
please complain to the webmaster [cite: bad_glimpsebin]");
    } elsif (($Conf->{'treename'} eq '/search')) {
        # Bug 465245 MXR search gives error for non tree in tree configuration
    } elsif (! -d $Conf->dbdir) {
        &fatal("Search isn't available;
please complain to the webmaster [cite: bad_dbdir]");
    } elsif (! -r $Conf->dbdir . '/.glimpse_index') {
        &fatal("Search isn't available;
please complain to the webmaster [cite: bad_glimpseindex]");
    } elsif ($searchtext ne "") {
        print '<hr>
';
        if ($find) {
            my $displayedfind = escape_comment($find);
            print '<p><i>Searching <a href="find?string=' . $displayedfind . '">these files</a>
for <a href="search?string=' . $displayedsearch . '">this text</a>.</i></p>';
        }

        print_ident_hints($requestedsearch);
        print $note;

        push @filters, $filter if $filter;
        if ($regexp) {
            $searchtext =~ s/([~;,><])/\\$1/g;
        } else {
            push @filters, escape_re($searchtext) if $search_sensitive;
            $searchtext =~ s/([~;,#><\-\$.^*^|()\!\[\]])/\\$1/g;
        }
        @execparams = ($Conf->glimpsebin,"-i","-H",$Conf->dbdir,'-y','-n');
        if ($find) {
            $find =~ s/-/\\-/g;
            push @execparams, ('-F', $find);
        }
        push @execparams, ('-e', $searchtext);
        my $glimpsepid;
        unless ($glimpsepid = open(GLIMPSE, "-|")) {
            open(STDERR, ">&STDOUT");
            $!='';
            exec(@execparams);
            print "Glimpse subprocess died unexpectedly: $!
";
            exit;
        }
if (0) {
local $, = "\n";
print "<!--

@execparams;


-->";
}

        $numlines = 0;
        my $search_case = undef;
        if ($search_sensitive) {
            $search_case = $searchtext;
        }

        print("<h1>$displayedsearch</h1>\n");

        my $hit_file_count = 0;
        my $hit_for_current_file = 0;
        my $prev_file;
        print "$styles
.status.searching {display:block}
.status {display: none}
$stylee
<p><b>
<span class='status searching'>Searching... </span>
<span class='status error_toolong'>Pattern too long. Use a maximum 29 characters.</span>
<span class='status matches_zero'>No matching files</span>
<span class='status matches_one'>Found one matching line</span>
<span class='status matches_n'>Found
$styles
.m0, .m1, .m2, .f0, .f1, .f2, .matches_f {display:none}
.m0_2 {display:inline}
$stylee";
for (my $q1=3;$q1--;) {
for (my $r1=0;$r1<10;++$r1) {
print "<span class='m$q1 m$q1"."_$r1'>$r1</span>";
}
}
print " matching lines
<span class='status matches_f'> in ";
for (my $q=3;$q--;) {
for (my $r=0;$r<10;++$r) {
print "<span class='f$q f$q"."_$r'>$r</span>";
}
}
print " files</span></span>
<span class='status matches_max'>Too many hits, displaying the first $maxhits</span>
</b></p>
";
        my $glimpse_error_reported = 0;
        my $glimpse_search_may_fail = 0;
        LINE: while (my $line = <GLIMPSE>) {
            if (!$numlines) {
                if ($line =~ /^Warning: No files were indexed! Exiting\.\.\./) {
                    print "No files in search index, please complain to the webmaster [cite: emptyglimpsetarget]<br>\n";
                    $glimpse_error_reported = 1;
                    last;
                }
                if ($line =~ /^in get_table: (table overflow|)/) {
                    print "Glimpse database is broken";
                    $glimpse_error_reported = 1;
                    last;
                }
                if ($line =~ /^Warning: pattern has words present in the stop-list: must SEARCH the files$/) {
                    next;
                }
                if ($line =~ /^Warning! Error in the format of the index!$/) {
                    next;
                }
                if ($line =~ /^[^:]*glimpse: unmatched '\[', '\]' \(use \\\[, \\\] to search for \[, \]\)/) {
                    $glimpse_search_may_fail = 1;
                    next;
                }
                if ($glimpse_search_may_fail && ($line =~ /^[^:]*glimpse: error in searching index$/)) {
                    $glimpse_search_may_fail = 0;
                    next;
                }
                if ($line =~ /^[^:]*:[^:]*(parse error at|unmatched)|^glimpse: error in searching index$/) {
                    print "Pattern can't be handled today, please file a
<a href='https://bugzilla.mozilla.org/enter_bug.cgi?product=Webtools&component=MXR&short_desc=glimpse+parse+error&bug_file_loc=please-fill-this-in'
>bug</a>.<br>";
                    $line = escape_comment($line);
                    print "<!--
$line
-->";
                    $glimpse_error_reported = 1;
                    next;
                }
                if ($line =~ /^[^:]*:[^:]*pattern has some meta-characters interpreted by agrep!/) {
                    print ("Pattern has some meta-characters.
<em>Try moving characters that are not letters (a-z) or numbers (0-9)
to the filter field</em><br>\n");
                    $glimpse_error_reported = 1;
                    next;
                }
                if ($line =~ /^[^:]*:[^:]*pattern too long/) {
                    print ("Pattern too long. Use a maximum of 29 characters.
<em>Try moving extra characters to the filter field.</em><br>\n");
                    $glimpse_error_reported = 1;
                    last;
                }
                if ($line =~ /^[^:]*:[^:]*regular expression too long, max is (\d+)/) {
                    print ("Regular expression pattern too long.
Use a maximum of $1 characters.
<em>Try moving extra characters to the filter field.</em><br>\n");
                    $glimpse_error_reported = 1;
                    last;
                }
                if ($line =~ /^[^:]*:[^:]*pattern '([^']*)' has no characters that were indexed/) {
                    print ("Pattern does not include any indexed characters.
<em>Try adding [a-z] as a regexp.</em><br>\n");
                    $glimpse_error_reported = 1;
                    last;
                }
            }
            next if $line =~
                m|using working-directory '.*' to locate dictionaries|;
            next if $search_sensitive && $line !~ /$search_case/;
            my $skip = 0;
            foreach $filter (@filters) {
                $skip = 1 unless $line =~ /$filter/;
            }
            next if $skip;

            my ($curr_file, undef, undef) =
                $line =~ /(.*?):\s*(\d+)\s*:(.*)/;
            my $lstyle = '';
            if ($prev_file ne $curr_file) {
                $prev_file = $curr_file;
                $hit_for_current_file = 1;
                ++$hit_file_count;
                if ($hit_file_count == 2) {
                    $lstyle .= ".matches_f {display: inline;}";
                }
                $lstyle .= toggle_style($hit_file_count, 'f');
            } elsif (defined $hitlimit &&
                     ++$hit_for_current_file > $hitlimit) {
                next LINE;
            }
            $numlines++;
            if ($numlines == 1) {
                $lstyle .= ".status.matches_one {display: block}
";
            } elsif ($numlines == 2) {
                $lstyle .= ".status.matches_one {display: none}
.status.matches_n {display: block}
";
            } else {
                $lstyle .= toggle_style($numlines, 'm');
            }
            if ($numlines > $maxhits) {
                $lstyle .= ".status.matches_n {display: none}
.status.matches_max {display: block}";
            }
            if ($lstyle) {
                print "$styles$lstyle$stylee";
            }
            display_line($line, $searchtext);
            last if $numlines > $maxhits;
        }
        my $none = $numlines == 0 ? '.status.matches_zero {display: block}' : '';
        print "$styles $none
.status.searching {display: none}
</style>";
        print ('</ul>') if $openlist;
        print "<p>";

        if ($numlines < 5) {
            close(GLIMPSE);
            $retval = $? >> 8;
        } else {
            kill 15, $glimpsepid;
            $retval = 0;
        }
        # The manpage for glimpse says that it returns 2 on syntax errors or
        # inaccessible files. It seems this is not the case.
        # We will have to work around it for the time being.

        if ($retval == 0) {
            if ($numlines == 0) {
                print "No matching files<br>
";
            } else {
                if ($numlines > $maxhits) {
                    print "<b>Too many hits, displaying the first $maxhits</b>
<br>";
                } else {
                    if ($numlines == 1) {
                        print "<b>Found one matching line</b>
<br>";
                    } else {
                        my $match_count = $hitlimit != 1
                                        ? " $numlines"
                                        : '';
                        my $in_files = $hit_file_count > 1
                                     ? " in $hit_file_count files"
                                     : '';
                        print "<b>Found$match_count matching lines$in_files</b>
<br>";
                    }
                }
            }
        } elsif ($retval == 1) {
            print "<b>No results found</b>
<br>";
        } elsif ($retval == 2) {
            # searching for '-' triggers this.
        } else {
            print "Unexpected return value $retval from Glimpse.
Please file a
<a href='https://bugzilla.mozilla.org/enter_bug.cgi?product=Webtools&component=MXR&short_desc=glimpse+unknown+retval&bug_file_loc=please-fill-this-in'
>bug</a>
";
        }
    }
}

($Conf, $HTTP, $Path, $head) = &glimpse_init;
$searchtext = $HTTP->{'param'}->{'string'};
$regexp = $HTTP->{'param'}->{'regexp'} || $Conf->{'regexp'};
$regexp = $regexp =~ /1|on|yes/ ? 1 : '';
$find = $HTTP->{'param'}->{'find'};
$findi = $HTTP->{'param'}->{'findi'};
$search_sensitive = defined $HTTP->{'param'}->{'case'} ? $HTTP->{'param'}->{'case'} =~ /1|on|yes/ : '';
$filter = $HTTP->{'param'}->{'filter'} ||
# '^[^\\0]*$'
'%5E%5B%5E\\0%5D%2A%24';
$hitlimit = cleanHitlimit($HTTP->{'param'}->{'hitlimit'}) || undef;

$filter =~ tr/+/ /;
$filter =~ s/%(\w\w)/chr(hex $1)/ge;

sub cleanHitlimit {
  my $hitLimit = shift;
  $hitLimit =~ s/\D//gs;
  return $hitLimit;
}

$find_warning = 0;
if (defined $findi && $findi ne '') {
  if (defined $find && $find ne '') {
   $find_warning = $find ne $findi;
  } else {
   #$find = $findi;
  }
}

sub cleanFind {
my $find = shift;
$find =~ s/["`'<>|()]+//g;
$find =~ s|%2f|/|gi;
$find =~ s|%24|\$|g;
$find =~ s|%5c|\\|gi;
$find =~ s|%2a|*|gi;
return $find;
}
$find = cleanFind($find);
$searchtext =~ tr/+/ /;
$searchtext =~ s/%([0-9a-f]{2})/chr(hex $1)/gie;
my $refresh;
my $tree = $HTTP->{'param'}->{'tree'};
if ($tree && ($tree ne $Conf->{'treename'})) {
    my @treelist = @{$Conf->{'trees'}};
    foreach my $othertree (@treelist) {
        next unless $othertree eq $tree;
push @tail, "string=" . url_quote($searchtext) if $searchtext ne '';
push @tail, "regexp=" . url_quote($regexp) if $regexp ne '';
push @tail, "case=" . url_quote($search_sensitive) if $search_sensitive ne '';
push @tail, "find=" . url_quote($find) if $find ne '';
push @tail, "findi=" . url_quote($findi) if $findi ne '';
push @tail, "filter=" . url_quote($filter) if $filter ne '';
push @tail, "hitlimit=" . url_quote($hitlimit) if $hitlimit ne '';
my $tail = $#tail >= 0 ? '?' . join "&", @tail : '';
$refresh .= "Refresh: 0; url=../$tree/search$tail
";
    }
}

print "$head$refresh
";
exit if $refresh ne '';

&makeheader('search');
&search;
&makefooter('search');

1;
