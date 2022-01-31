#!/usr/bin/perl
# $Id: source,v 1.18 2006/12/07 04:59:38 reed%reedloden.com Exp $
# source --  Present sourcecode as html, complete with references
#
#  Arne Georg Gleditsch <argggh@ifi.uio.no>
#  Per Kristian Gjermshus <pergj@ifi.uio.no>
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
use SimpleParse;
use LXR::Common;
use LXR::Config;
use Cwd;
use File::Basename;

my $force;

sub diricon {
    my ($img, $link);
    if ($filename eq '..') {
        $img = "/media/icons/folder.png";
        $link = $parentdir;
    } else {
        my $dir =  $Path->{'real'}.$filename;
        $dir =~ s#/$##;
        if (-l $dir) {
            $img = "/media/icons/goto_folder.png";
        } else {
            $img = "/media/icons/folder.png";
        }
        $link = $Path->{'virt'}.$filename;
    }
    $link =~ s/&/&amp;/g;
    $link =~ s/"/&quot;/g;
    $link =~ s/</&lt;/g;
    $link =~ s/>/&gt;/g;
    return "<img class=\"dir icon\" border=\"0\" src=\"$img\" style\=\"margin-top: 4px; margin-bottom: 0px;\">";
}

sub dirnamehtml {
    if ($filename eq '..') {
        return(&fileref("Parent directory", $parentdir));
    } else {
        return(&fileref($filename, $Path->{'virt'}.$filename));
    }
}

sub resolvelink {
    my $almost = readlink(shift);
    my $rel = shift;
    unless ($almost =~ m{^/}) {
        $almost = $rel . '/' . $almost;
    }
    return $almost;
}

sub fileicon {
    my $img;
    my $tag = 'img';
    my $realf = $Path->{'real'}.$filename;
    if (-l $realf && !-e resolvelink($realf, $Path->{'real'})) {
        $img = "/media/icons/exclude_path.png";
    } elsif (!-r $realf) {
        $img = "/media/icons/unknown.png";
    } elsif ($filename =~ /^.*\.ch|c[cs]$/) {
        $img = "/media/icons/c.png";
    } elsif ($filename =~ /^.*\.css$/) {
        $img = "/media/icons/txt.png";
    } elsif ($filename =~ /^.*\.bin$/) {
        $img = "/media/icons/binary.png";
    } elsif ($filename =~ /^.*\.py$/) {
        $img = "/media/icons/py.png";
    } elsif ($filename =~ /^.*\.(mk|build|mozbuild|m4|manifest)$/) {
        $img = "/media/icons/build.png";
    } elsif ($filename =~ /^.*\.xul$/) {
        $img = "/media/icons/ui.png";
    } elsif ($filename =~ /^.*\.xml$/) {
        $img = "/media/icons/xml.png";
    } elsif ($filename =~ /^.*\.java$/) {
        $img = "/media/icons/java.png";
    } elsif ($filename =~ /^.*\.js$/) {
        $img = "/media/icons/js.png";
    } elsif ($filename =~ /^.*\.(idl|cpp?|hh|s)$/) {
        $img = "/media/icons/cpp.png";
    } elsif (isImage($filename, 1)) {
        $img = "/media/icons/image.png";
        my $s = (-s $realf);
        if ($s < 10<<10) {
            $img = "$filename?raw=1";
            if ($filename =~ /\.svg$/i) {
                my $ctype = 'image/svg+xml';
                $img .= "&ctype=$ctype";
                $tag = "embed type='$ctype'";
            }
        }
    } else {
        $img = "/media/icons/txt.png";
    }
    my $link = $Path->{'virt'} . $filename;
    $link =~ s/&/&amp;/g;
    $link =~ s/"/&quot;/g;
    $link =~ s/</&lt;/g;
    $link =~ s/>/&gt;/g;
    return "<$tag class=\"file icon\" border=\"0\" src=\"$img\">";
}


sub filename {
    my $string =
        &fileref($filename, $Path->{'virt'}.$filename);
    if (isHTML($filename) || isCSS($filename) || isREADME($filename)) {
        $string =~ s/(a href=".*)(")/$1?force=1$2/g;
    }
    return $string;
}


sub filesize {
    my $templ = shift;
    my $s = (-s $Path->{'real'}.$filename);
    my $str;
    if ($s < 1<<10) {
        $str = "$s";
    } else {
#        if ($s < 1<<20) {
            $str = ($s>>10) . "k";
#        } else {
#            $str = ($s>>20) . "M";
#        }
    }
    return(&expandtemplate($templ,
                           ('bytes',        sub {return($str)}),
                           ('kbytes',        sub {return($str)}),
                           ('mbytes',        sub {return($str)})
                           ));
}


sub modtime {

    my $current_time = time;
    my $realf = $Path->{'real'}.$filename;
    return "Missing" unless -e $realf;
    my $file_time = (stat($realf))[9];

    my @t = gmtime($file_time);

    my @months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
    my ($sec, $min, $hour, $mday, $mon, $year) = @t;
    $year += 1900;
    $mon = $months[$mon];

    my $one_hour = (60 * 60);
    my $six_months = $one_hour * 24 * int(365/2);

    if ($file_time <= ($current_time - $six_months) ||
        $file_time >= ($current_time + $one_hour)) {
        return sprintf("%s %2d  %04d", $mon, $mday, $year);
    } else {
        return sprintf("%s %2d %02d:%02d", $mon, $mday, $hour, $min);
    }
}

sub bgcolor {
    if (!($line % 1)) {
        $color = ($color eq "#EEEEEE")? "#FFFFFF": "#EEEEEE";
    }
    return($color);
}


sub direxpand {
    my $templ = shift;
    my $direx = '';
    local $line = 0;
    local $filename;
    local $color="#FFFFFF";
    my $virtpath = $Path->{'virt'};
    my $realpath = $Path->{'real'};

    foreach $filename (@dirs) {
        $line++;
        next if $filename =~ /(obj-(.*))\//;
        $direx .= &expandtemplate($templ,
            ('iconlink',                \&diricon),
            ('namelink',                \&dirnamehtml),
            ('filesize',                sub {return('-')}),
            ('modtime',                \&modtime),
            ('bgcolor',                \&bgcolor),
            ('description',        \&descexpand));
    }

    foreach $filename (@files) {
        $line++;
        next if $filename =~ /^.*\.[oa]$|^00-INDEX$/;
        $direx .= &expandtemplate($templ,
            ('iconlink',        \&fileicon),
            ('namelink',        \&filename),
            ('filesize',        \&filesize),
            ('modtime',                \&modtime),
            ('bgcolor',                \&bgcolor),
            ('description',        \&fdescexpand));
    }

    return($direx);
}

sub unreadable {
    my ($realf, $reald) = @_;
    unless ($reald) {
        $realf =~ m{^(.*)/};
        $reald = $1;
    }
    return " links to a file that does not exist." if -l $realf && !-e resolvelink($realf, $reald);
    return " does not exist." unless -e $realf;
    return " is not readable." unless -r $realf;
    return " could not be read for an unknown reason.";
}

sub printdir {
    my $template;
    my $index;
    local %index;
    local @dirs;
    local @files;
    local $parentdir;

    $template = "<ul>\n\$files{\n<li>\$iconlink \$namelink\n}</ul>\n";
    if ($Conf->htmldir) {
        unless (open(TEMPL, '<:unix', $Conf->htmldir)) {
            &warning("Template ".$Conf->htmldir.unreadable($Conf->htmldir), 'htmldir');
        } else {
            local $/;
            $template = <TEMPL>;
            close(TEMPL);
        }
    }

    if (opendir(DIR, $Path->{'real'})) {
        foreach $f (sort {lc $a cmp lc $b} (grep/^[^\.]/,readdir(DIR))) {
            if (-d $Path->{'real'}.$f) {
                if ($f =~ /(^CVS|^\.svn|_files)$/) {
                    #skip it
                } else {
                    push(@dirs,"$f/");
                }
            } else {
                push(@files,$f);
            }
        }
        closedir(DIR);
    } else {
        print("<p align=center>\n<i>This directory".unreadable($Path->{'real'})."</i>\n");
        if ($Path->{'real'} =~ m#(.+[^/])[/]*$#) {
            if (-e $1) {
                &warning("Unable to open ".$Conf->{'treename'}.$Path->{'virt'}, 'virt');
            }
        }
        return;
    }

    if ($Path->{'virt'} =~ m#^(.*/)[^/]*/$#) {
        $parentdir = $1;
        unshift(@dirs, '..');
    }

    # print the description of the current directory
    dirdesc($Path->{'virt'});

    #print the listing itself
    print(&expandtemplate($template,
                          ('files',        \&direxpand)));
}

sub isHTML {
    return 0 if $force;
my $file = shift;
    return ($file =~ /\.html?$/);
}

sub isCSS {
    return 0 if $force;
my $file = shift;
    return ($file =~ /stylesheet\.(css)$/) ||
          (($file =~ /\.(css)$/) && $ENV{HTTP_ACCEPT} !~ 'text/html');
}

sub isImage {
    return 0 if $force;
    my ($file, $ignoreAccept) = @_;
    return 0 unless $ignoreAccept || $ENV{HTTP_ACCEPT} !~ 'text/html';
    return $file =~ /\.([jmp][pnm]e?g|gif|ico)$/i;
}

sub isREADME {
    return 0 if $force;
my $file = shift;
    return $file =~ /README$/i;
}

sub noWrap {
my $file = shift;
    return $HTTP->{'param'}->{'raw'} ||
           isHTML($file) ||
           isImage($file) ||
           isCSS($file);
}

sub printfile {
    my $string;
    my $file = $Path->{'file'};

    unless ($file) {
        &printdir;
    } else {
        my ($openresult, $cat);
        if (defined $HTTP->{'param'}->{'rev'} &&
            $HTTP->{'param'}->{'rev'} =~ /([a-f0-9]+)/i) {
            $cat = 'cat -r '.$1;
        }
        if ($cat) {
            my $dir = getcwd;
            chdir $Path->{'real'};
            my $verb;
            if (-d '.svn') {
                $verb = 'svn';
            } else {
                for my $vcs (qw(hg bzr)) {
                    unless (system("$vcs st $file")) {
                        $verb = $vcs;
                        last;
                    }
                }
            }
            if ($verb) {
                my $command = "$verb $cat ".$Path->{'realf'}.' |';
                $openresult = open(SRCFILE, '<:unix', $command);
            }
            chdir $dir;
        } else {
            $openresult = open(SRCFILE, '<:unix', $Path->{'realf'});
        }
        if ($openresult) {
if (0) {
print "<!--

";
foreach my $key (keys %ENV)
{
print "export $key=".'"'.$ENV{$key}.'"'."
";
}
print "-->
";
}
            my $kind = getMimeType($file);
            if (isHTML($file)) {
                local $/ = undef;
                print <SRCFILE>;
            } elsif (isCSS($file)) {
$head = "Content-Type: text/css\r\n\r\n";
                print $head;
                local $/ = undef;
my $body = <SRCFILE>;
                print $body;
            } elsif (isImage($file)) {
                my $kind = 'x-unknown';
                $kind = 'jpeg' if $file =~ /\.jpe?g$/i;
                $kind = 'pjepg' if $file =~ /\.pjpe?g$/i;
                $kind = 'gif' if $file =~ /\.gif$/i;
                $kind = 'png' if $file =~ /\.[jp]ng$/i;
                $kind = 'bitmap' if $file =~ /\.bmp$/i;
                $kind = 'svg+xml' if $file =~ /\.svg$/i;
                $kind = 'x-icon' if $file =~ /\.(ico|ani|xpm)$/i;
                print
$head = "Content-Type: image/$kind\r\n\r\n";
                local $/ = undef;
my $body = <SRCFILE>;
                print $body;
            } elsif (!$force && isREADME($file)) {
                print("<pre lang='en'>");
                while(<SRCFILE>) {
                        $string = $string . $_;
                }
                print(markupstring($string, $Path->{'virt'}));
                print("</pre>");
            } elsif ($skip_wrap) {
                local $/ = undef;
                print <SRCFILE>;
            } else {
                if (-e "$Path->{'root'}/client.mk" && ($file =~ /\.idl$/)) {
                  my $base = basename($file, ".idl");
                  my $dir = $Path->{'virt'};
                  $dir =~ s#^/([^/]+)(.*)#$1#;
                  my $doxRoot = 'http://doxygen.db48x.net/mozilla/html/';
                  my $doxURL = "${doxRoot}interface${base}";

# safari 1 gives alert() if it finds an <object> for svg and has no plugin
# ff2 gives a non grown image for <object> for svg, i.e. so badly truncated
# that no one could possibly want it
                  print qq#
<!-- <p>Inheritance diagram for $base:</P>
<p align="center">
  <object data="${doxURL}__inherit__graph.svg" type="image/svg+xml" border="0">
    <param name="src" value="${doxURL}__inherit__graph.svg">

  <a href="${doxURL}__inherit__graph.svg">
    <img src="${doxURL}__inherit__graph.png" alt="Inheritance graph" border="0">
  </a>
</p>
<p>Collaboration diagram for $base:</p>
<p align="center">
  <a href="${doxURL}__coll__graph.svg">
    <img src="${doxURL}__coll__graph.png" alt="Collaboration graph" border="0">
  </a>
</p>
<p align="center">
  [ <a href="${doxURL}.html"><i>$base</i> Interface Reference</a> |
  <a href="${doxRoot}graph_legend.html">Graph Legend</a> ]
</p> -->
#;
                }
                print("<pre lang='en'>");
               &markupfile(\*SRCFILE, $Path, $file,
                             sub { print shift }, $force);
                print("</pre>");
            }
            close(SRCFILE);
        } else {
            print("<p align=center>\n<i>This file".unreadable(url_quote($Path->{'realf'}))."</i>\n");
            if (-l $Path->{'realf'}) {
                print('<br><tt>'.unreadable(url_quote(readlink($Path->{'realf'})))."</tt></p>\n");
            }
            $rev = "&rev=$rev" if ($rev ne '');
            my $hint = $Path->{'virt'};
            if (defined $hint && $hint ne '/') {
              $hint = clean_hint($hint);
              $hint = "&amp;hint=$hint";
            } else {
              $hint = '';
            }
            my $markstring = '';
            if (defined $HTTP->{'param'}->{'mark'}) {
              my $marks = clean_mark($HTTP->{'param'}->{'mark'});
              if ($marks ne '') {
                $markstring = "&amp;mark=$marks";
              }
            }
            print("<p>Maybe you can <a href='" .
                   $Conf->baseurl .
                   "/find?string=/" .
                   url_quote($file) .
                   $hint .
                   $markstring .
                   $rev .
                  "'>find it elsewhere</a>.\n");
            if (-f $Path->{'realf'}) {
                &warning("Unable to open ".$Conf->{'treename'}.$Path->{'virtf'}, 'virtf');
            }
        }
    }
}

($Conf, $HTTP, $Path, $head) = &init($0);

my $skip_wrap = 0;
sub http_header_stuff {
my $exit = 0;

my $tree = $HTTP->{'param'}->{'tree'};

#only allow access to registered roots
#for anything else redirect to the directory containing source
unless (defined $Path->{'root'}) {
    #if we're accessed as source/ then we need to be a bit more directed.
    my $path = $ENV{'PATH_INFO'};
    $path =~ s|[^/]+||g;
    $path =~ s{/}{../}g;
    my $prefix = $path || './';
    my $refresh = "Refresh: 0; url=$prefix
";
    $head .= "$refresh
";
    $exit = 1;
} elsif (defined $Path->{'rewriteurl'}) {
    my $path = $ENV{'PATH_INFO'};
    my $refresh = "Refresh: 0; url=$rewriteurl$path
";
    $head .= "$refresh
";
    $exit = 1;
}

if (($ENV{'PATH_INFO'} !~ m|/$|) && (-d $Path->{'realf'})) {
 # access to rootname/source needs to be redirected to rootname/source/
 my $entryname = 'source';
 if ($ENV{'PATH_INFO'} ne '') {
  my @dirs = split m|/|, $Path->{'realf'};
  $entryname = $dirs[$#dirs];
 }
 my $refresh = "Refresh: 0; url=$entryname/
";
    $head .= "$refresh
";

 $exit = 1;
}

$force = $HTTP->{'param'}->{'force'};
$force = (defined $force && $force =~ /1|on|yes/ ? 1 : 0);

unless ($exit) {
    my $baseurl = $Conf->{baseurl};
    my $localurl = $baseurl . '/source' . $ENV{'PATH_INFO'};
    $localurl = url_quote($localurl);
    $localurl =~ s/%3A/:/;
    $localurl =~ m{(^.*/)/*[^/]+/*(?:|\?.*)$};
    my $parenturl = $1;
    if (!$ENV{'BINOC_CGI'}) {
      $head .=
'Link: <' . $localurl . '?force=1>; rel="First"; title="Marked up"
Link: <' . $localurl . '?raw=1>; rel="Last"; title="Raw"
';
    }
}

    if (defined($HTTP->{'param'}->{'raw'})) {
        unless (open(RAW, "<:unix", $Path->{'realf'})) {
            $Path->{'realf'} =~ m{/([-a-z0-9_.]+)$}i;
            print "Status: 404 File Not Found
Link: <" . $Conf->{baseurl} . "/find?string=$1>; rel='Contents'; title='Find file'
Content-Type: text/html

";
            my $virtf = $Path->{'virtf'};
            $virtf =~ s/</&lt;/g;
            print "<h1>File Not Found</h1>
<h4><em>Couldn't open $Conf->{'treename'}:$virtf";
            exit;
        }
        if (!$ENV{'BINOC_CGI'}) {
            print "$head";
        }
        while (<RAW>) {
            print;
        }
        close(RAW);
        exit;
    }

$exit = 1 if $ENV{'REQUEST_METHOD'} eq 'HEAD';

#if the file is html then don't print a header because the file
#has its own -dme
my $strange_inexplicable_check = (-f $Path->{'real'}.$Path->{'file'});
$skip_wrap = $Path->{'file'} && noWrap($Path->{'file'});
print "$head
" if (!$Path->{'file'} || isHTML($Path->{'file'}) || !$skip_wrap);
exit if $exit;
}

&http_header_stuff;

sub html_header_stuff {
if (
    !$skip_wrap
   ) {
    if ($Path->{'file'}) {
        &makeheader('source');
    } else {
        &makeheader('sourcedir');
    }
}
}

&html_header_stuff;

&printfile;

sub footer_stuff {
if (
    !$skip_wrap
   ) {
    if ($Path->{'file'}) {
        &makefooter('source');
    } else {
        &makefooter('sourcedir');
    }
}
}

&footer_stuff;

1;
