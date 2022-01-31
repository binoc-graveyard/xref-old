#!/usr/bin/perl
# $Id: ident,v 1.8 2006/12/07 04:59:38 reed%reedloden.com Exp $

# ident --	Look up identifiers
#
#	Arne Georg Gleditsch <argggh@ifi.uio.no>
#	Per Kristian Gjermshus <pergj@ifi.uio.no>
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
use DB_File;

@tyy= (
       ('I', 'interface'),
       ('C', 'class'),                  # C++
       ('c', '(forwarded) class'),      # C++
       ('M', 'preprocessor macro'),
       ('F', 'function'),
       ('f', 'function prototype'),
       ('T', 'type'),
       ('S', 'struct type'),
       ('E', 'enum type'),
       ('U', 'union type'),
       ('V', 'variable'),
       ('R', 'reference'),
      );
%ty = @tyy;

sub list_links
{
  my ($t, $fnam, $concise, $lines) = @_;
  @fpos = sort { $a <=> $b } split(/,/, $lines);
  if ($concise && /:/ !~ $lines) {
    print("<li>", &fileref("$fnam", "/$fnam"),
          ", ",$#fpos+1,' time'.($#fpos?'s':'')."\n");
  } else {
    print("<li>". &fileref("$fnam", "/$fnam"));
    unless ($concise) {
      my $blamelines = $lines;
      $blamelines =~ s/:[^,]*//g;
      print(&blamerefs($fnam, $blamelines));
    }
    my $closefilereader;
    my %filedesc = (line => 0, data => '');
    if (open FILEREADER, '<', $Path->{'realf'}) {
      $closefilereader = 1;
      $filedesc{'line'} = 0;
      $filedesc{'data'} = '';
    } else {
      print "<!-- couldn't open $fnam -->";
    }
    sub getline {
      my ($filedesc, $lineno) = @_;
      my ($fileline, $lastline) = ($$filedesc{'line'}, $$filedesc{'data'});
      if ($fileline == $lineno) {
        return $lastline;
      }
      while (++$fileline < $lineno) {
        my $junk = <FILEREADER>;
        last if eof FILEREADER;
      }
      $lastline = <FILEREADER>;
      ($$filedesc{'line'}, $$filedesc{'data'}) = ($fileline, $lastline);
      return $lastline;
    }
    print("\n <ul>");
    foreach (@fpos) {
      my ($line, @clss) = split(/:/, $_);
      print("<li>", &fileref("line $line",
            "/$fnam", $line));
      if (@clss) {
        if ($t eq 'F' || $t eq 'f') {
          print(", as member of ");
          if ($xref{$clss[0]}) {
            print(&idref("class $clss[0]", $clss[0]));
          } else {
            print("class $clss[0]");
          }
        } elsif ($t eq 'C') {
          local $,;
          print(", inheriting <ul>\n");
          foreach (@clss) {
            if ($,) {
              print $,;
            } else {
              $,=',';
            }
            print("<li>");
            if ($xref{$_}) {
              print("class ".&idref($_, $_));
            } else {
              print("class <a title='unindexed fixme'>$_</a>");
            }
          }
          print("  </ul>");
        }
      }
      print " -- <span class='p'>" .
            markupstring(getline(\%filedesc, $line), $Path->{'virt'}) .
            "</span>\n";
    }
    close FILEREADER if $closefilereader;
    print(" </ul>\n");
  }
}

sub ident {
    my $concise = 0;

    print('<p class=desc>
Type the full name of an identifier
(a function name, variable name, typedef, etc.)
<br>to summarize. Matches are <u>case-sensitive</u>.');
    if ($Conf->{'treename'} ne '') {
        print &bigexpandtemplate('<script src="/media/scripts/script.js"></script>');
    }
    print('<form id=ident name=ident method=get action="ident" class="beforecontent">
');

    foreach ($Conf->allvariables) {
        if ($Conf->variable($_) ne $Conf->vardefault($_)) {
            print("<input type=hidden name=\"",$_, "\" ",
                  "value=\"", $Conf->variable($_), "\">\n");
        }
    }

    print('<b><label for="i">Identifier:</label></b>
<input type=text id="i" name="i"
value="'.$identifier.'" size=50>
<input type=submit value="Find">
');
    if ($Conf->{'treename'} ne '') {
        print '
<label for="tree">using tree:</label>
<select name="tree" id="tree" onchange="changetarget()">
';
        my @treelist = @{$Conf->{'trees'}};
        foreach my $othertree (@treelist) {
            my $default=$othertree eq $Conf->{'treename'} ? ' selected=1' : '';
            print "<option$default value='$othertree'>$othertree</option>
";
        }
        print (qq{</select>});
    }

    my $value = $filter;
    $value =~ s/&/&amp;/g;
    $value =~ s/"/&quot;/g;
    $value =~ s/</&lt;/g;
    $value =~ s/>/&gt;/g;
    print '<br>
<label for="filter">Limit output to pattern:</label>
<input type=text id="filter" name="filter" value="'.
$value.'" size=30>';

    print "<br>
<input type='checkbox' value='1' ";
    print "checked='checked' " if $strict == 1;
    print "id='strict' name='strict'
><label for='strict'>Don't match C++, JS, and IDL variants</label>
</form>
";

    if ($identifier) {
	tie(%xref, "DB_File", $Conf->dbdir."/xref",
	    O_RDONLY, undef, $DB_HASH) ||
		&fatal('No cross reference database is available for "'.$Conf->{'treename'}.'" please complain to the webmaster [cite: xref]');

	@refs = split(/\t/,$xref{$identifier});
        my $searchId = $identifier;
        my $searchIdFilter;
        unless ($strict) {
            my $genident = $identifier;
            my ($identtype, $ufirst, $lfirst);
            if ($genident =~ s/^([GSgs]et)([A-Z])//) {
                $identtype = $1;
                $ufirst = $2;
                $lfirst = lc $ufirst;
                $searchIdFilter = "([GSgs]et|\\b)[$ufirst$lfirst]$genident";
                $searchId = "$lfirst$genident";
            } elsif ($genident =~ s/^([a-z])//i) {
                $ufirst = uc $1;
                $lfirst = lc $ufirst;
                $searchIdFilter = "[$ufirst$lfirst]$genident";
            }
            my @flavors = (
                "get$ufirst$genident",
                "set$ufirst$genident",
                "Get$ufirst$genident",
                "Set$ufirst$genident",
                "$ufirst$genident",
                "$lfirst$genident",
            );
            @refs = ();
            foreach my $flavor (@flavors) {
                next if defined $identtype && $flavor =~ /^([GSgs]et)/ && $identtype !~ /$1/i;
                push @refs, split(/\t/,$xref{$flavor});
            }
        } else {
            $searchIdFilter = "\\b$identifier";
        }
my $identifier = $identifier;
$identifier =~ s/&/&amp;/g;
$identifier =~ s/>/&gt;/g;
$identifier =~ s/</&lt;/g;
$identifier =~ s/"/&quot;/g;
        print("<h1>$identifier</h1>\n");
my @tail = ();
push @tail, "string=$searchId" if $searchId ne '';
push @tail, "find=$filter" if $filter ne '';
push @tail, "filter=$searchIdFilter" if $searchIdFilter ne '';
my $tail = $#tail >= 0 ? '?' . join "&", @tail : '';
$tail =~ s/&/&amp;/g;
$tail =~ s/>/&gt;/g;
$tail =~ s/</&lt;/g;
$tail =~ s/"/&quot;/g;

        print qq{<p><i>If you can't find what you're looking for, you can always <a href="search$tail"
>perform a free-text search</a> for it.</i></p>};

        my %f = {};
	if (@refs) {
            -f $Conf->dbdir."/fileidx" ||
                &fatal(
'Cross reference database is missing its file list for "'.
$Conf->{'treename'}.'" please complain to the webmaster [cite: nofileidx]');
            -r $Conf->dbdir."/fileidx" ||
                &fatal(
'Cross reference database file list is not readable for "'.
$Conf->{'treename'}.'" please complain to the webmaster [cite: norfileidx]');

	    tie(%fileidx, "DB_File", $Conf->dbdir."/fileidx",
		O_RDONLY, undef, $DB_HASH) ||
		    &fatal('Error opening Cross reference file list for "'.
$Conf->{'treename'}.'" please complain to the webmaster [cite: fileidx]');

            my %normal_refh = {}, %fancy_refs = {};
            my %big_map = {};
            foreach $t (keys(%ty)) {
                $big_map{$t} = {};
            }
            my %local_map;
            foreach my $ref (@refs) {
                if ($ref =~ /^(.)(.*?):(.*?)(?:|:(.*?))$/) {
my ($refkind, $reffnum, $refline, $classes) = ($1, $2, $3, $4);
                    next if defined $filter && $fileidx{$reffnum} !~ /$filter/;
                    foreach my $lineref (split(/,/, $refline)) {
                        my $append = (defined $classes)
                                   ? "$lineref:$classes"
                                   : $lineref;

                        if ($big_map{$refkind}{$reffnum}) {
                            $big_map{$refkind}{$reffnum} = $big_map{$refkind}{$reffnum} . ",$append";
                        } else {
                            $big_map{$refkind}{$reffnum} = $append;
                        }

                        my $miniref = "$reffnum:$lineref";
                        if ($refkind ne 'R' && $ty{$refkind}) {
                            delete $normal_refh{$miniref};
                            $fancy_refs{$miniref} = $refkind;
                            $f{$refkind} .= "$miniref\t";
                        } else {
                            $normal_refh{$miniref} = $refkind unless defined $fancy_refs{$miniref};
                        }
                    }
                }
            }

            foreach $t (@tyy) {
                next unless ($f{$t});
                print("<p style=\"margin-bottom: 0px;\">Defined as a $ty{$t} in:</p><ul>\n");

                my %kind_map = %{$big_map{$t}};
                foreach $fnum (sort { $a <=> $b } keys %kind_map) {
                    my $fnam = $fileidx{$fnum};
                    foreach my $filelist ($kind_map{$fnum}) {
                        list_links($t, $fnam, $concise, $filelist);
                    }
                }
                print("</ul>");
            }

            my @normal_refs = keys %normal_refh;
            %normal_refh = ();
            foreach (@normal_refs) {
                if (/^(.+):([\d,]+)/) {
                    if (defined $normal_refh{$1}) {
                        $normal_refh{$1} .= ",$2";
                    } else {
                        $normal_refh{$1} = $2;
                    }
                }
            }
            @normal_refs = ();
            my $ref_count = scalar(keys %normal_refh);
            print('<p style="margin-bottom: 0px;">Referenced '.($ref_count > 1 ? "(in $ref_count files total) " : '')."in:\n</p>",
                  "<ul>\n");
            foreach (sort { $a <=> $b } keys %normal_refh) {
                list_links($t, $fileidx{$_}, $concise, $normal_refh{$_});
            }
            print("</ul>\n");
            untie(%fileidx);

        } else {
            print("<br><b>Not used</b>");
        }

        untie(%xref);
    }
}

($Conf, $HTTP, $Path, $head) = &init;

$identifier = $HTTP->{'param'}->{'i'};
$identifier =~ s/"/\&quot;/g;
$filter = $HTTP->{'param'}->{'filter'};
if ($filter) {
    $filter =~ s/^(?:\+|\s|%20)*(.*?)(?:\+|\s|%20)*$/$1/;
}
if ($identifier) {
    $identifier =~ s/^(?:\+|\s|%20)*(.*?)(?:\+|\s|%20)*$/$1/;
    if (!$filter &&
        $identifier =~ /^(.*?)(?:\+|\s|%20)*::(?:\+|\s|%20)*(.*)$/) {
        ($filter, $identifier) = ($1, $2);
    }
}
my $scriptidly = $HTTP->{'param'}->{'scriptidly'};
$scriptidly = $scriptidly =~ /1|yes/ ? 1 : 0 if defined $scriptidly;
$strict = $HTTP->{'param'}->{'strict'};
$strict = $strict =~ /1|yes/ ? 1 : 0 if defined $strict;
$strict = 0 if $scriptidly;

$strict = 1;
my $tree = $HTTP->{'param'}->{'tree'};
if ($tree && ($tree ne $Conf->{'treename'})) {
    my @treelist = @{$Conf->{'trees'}};
    foreach my $othertree (@treelist) {
        next unless $othertree eq $tree;
my @tail = ();
push @tail, "i=" . url_quote($identifier) if $identifier ne '';
push @tail, "filter=" . url_quote($filter) if $filter ne '';
push @tail, "strict=1" if $strict;
my $tail = $#tail >= 0 ? '?' . join "&", @tail : '';
$head .= "Refresh: 0; url=../$tree/ident$tail
";
    }
}
print "$head
";

&makeheader('ident');
&ident;
&makefooter('ident');

1;
