#!/usr/bin/perl
# $Id: Local.pm,v 1.9 2006/12/07 04:59:38 reed%reedloden.com Exp $
# Local.pm -- Subroutines that need to be customized for each installation
#
#	Dawn Endico <endico@mozilla.org>
#
######################################################################
# This package is for placing subroutines that are likely to need
# to be customized for each installation. In particular, the file
# and directory description snarfing mechanism is likely to be
# different for each project.

package Local;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(&fdescexpand &descexpand &dirdesc &convertwhitespace
             &localexpandtemplate
	     &isForce &isImage &isHTML &isCSS &getMimeType
            );

use lib 'lib';
use LXR::Common;
use File::Glob qw(bsd_glob :globally :nocase);

# dme: Create descriptions for a file in a directory listing
# If no description, return the string "\&nbsp\;" to keep the
# table looking pretty.
#
# In mozilla search the beginning of a source file for a short 
# description. Not all files have them and the ones that do use 
# many different formats. Try to find as many of these without
# printing gobbledygook or something silly like a file name or a date.
#
# Read in the beginning of the file into a string. I chose 60 because the 
# Berkeley copyright notice is around 40 lines long so we need a bit more 
# than this.
#
# It's common for file descriptions to be delimited by the file name or
# the word "Description" which precedes the description. Search the entire
# string for these. Sometimes they're put in odd places such as inside
# the copyright notice or after the code begins. The file name should be
# followed by a colon or some pattern of dashes. 
#
# If no such description is found then use the contents of the "first"
# comment as the description. First, strip off the copyright notice plus
# anything before it. Remove rcs comments. Search for the first bit of
# code (usually #include) and remove it plus anything after it. In what's
# left, find the contents of the first comment, and get the first paragraph.
# If that's too long, use only the first sentence up to a period. If that's 
# still too long then we probably have a list or something that will look 
# strange if we print it out so give up and return null.
#
# Yes, this is a lot of trouble to go through but its easier than getting
# people to use the same format and re-writing thousands of comments. Not
# everything printed will really be a summary of the file, but still the
# signal/noise ratio seems pretty high.
#
# Yea, though I walk through the valley of the shadow of pattern
# matching, I shall fear no regex.
sub fdescexpand {
    # use global vars here because the expandtemplate subroutine makes
    # passing parameters impossible. Use $filename from source and
    # $Path from Common.pm
    my $filename = $main::filename;
    my $copy= "";
    local $desc= "";
    my $lic_length = 40;
    my $lic_start;
    my $maxlines = 20; #only look at the beginning of the file
    my $excessivelines = 200; #sometimes people are too verbose for our own good
    my $inlicense = 0;

    #for broken symlinks list their target
    my $realf = $Path->{'real'}.'/'.$filename;
    if (!-e $realf && -l $realf) {
        $desc = readlink $realf;
        $desc =~ s/\&/&amp;/g;
        $desc = '<tt>'.$desc.'</tt>';
        return $desc;
    }
    #handle man pages
    if ($filename =~ /\.\d+\w?(?:\.in|)$/) {
        return descmanfile($realf);
    }
    #ignore files that are neither source code nor html
    return ("\&nbsp\;") unless
	    ($filename =~ /\.(?:[chr](?:p?p?|c)|mm?|idl|java|p[lm]|(?:pl|vb|j|c|re)s|vb|html?)$/) ||
	    0;

    if (open(FILE, $realf)) {
        while(<FILE>){
            my $descline = $_;
	    $desc .= $descline ;
            if (defined $lic_start && $descline =~ /END.*LICENSE/) {
                my $lic_delta = $. - $lic_start;
                $lic_length = $lic_delta if $lic_delta > $lic_length;
                $inlicense = 0;
            }
            if (!defined $lic_start && $descline =~ /BEGIN.*LICENSE/) {
                $lic_start = $.;
                $inlicense = 1;
            }
            if($. > $excessivelines) {
                last;
            }
	    if(!$inlicense && $. > $lic_length + $maxlines) {
		last;
	    }
	}
	close(FILE);
    } 
    if ($filename =~ /\.html?$/) {
        if ($desc =~ m{<title[^>]*>(.*)?</title}is) {
            $desc = $1;
            $desc =~ s/<[^>].*>//g;
            return $desc;
        }
    }

    # sanity check: if there's no description then stop
    if (!($desc =~ /\w/)){
	return("\&nbsp\;");
    }

    # save a copy for later
    $copy = $desc;

    # Look for well behaved <filename><separator> formatted 
    # descriptions before we go to the trouble of looking for
    # one in the first comment. The whitespace between the 
    # delimiter and the description may include a newline.
    if (($desc =~ s/(?:.*?\Q$filename\E\s*?- ?-*\s*)([^\n]*)(?:.*)/$1/sgi) || 
        ($desc =~ s/(?:.*?\Q$filename\E\s*?:\s*)([^\n]*)(?:.*)/$1/sgi) ||
        ($desc =~ s/(?:.*?Description:\s*)([^\n]*)(?:.*)/$1/sgi) 
	){
        # if the description is non-empty then clean it up and return it
        if ($desc =~ /\w/) {
            #strip trailing asterisks and "*/"
            $desc =~ s#\*/?\s*$##;
            $desc =~ s#^[^\S]*\**[^\S]*#\n#gs;

            # Strip beginning and trailing whitespace
            $desc =~ s/^\s+//;
            $desc =~ s/\s+$//;

            # Strip junk from the beginning
            $desc =~ s#[^\w]*##ms;

            #htmlify the comments making links to symbols and files
            $desc = markupstring($desc, $Path->{'virt'});
            return($desc);
        } 
    }

    # we didn't find any well behaved descriptions above so start over 
    # and look for one in the first comment
    $desc = $copy;

    # Strip off code from the end, starting at the first cpp directive
    $desc =~ s/\n#.*//s;

    # Strip off code from the end, starting at typedef
    $desc =~ s/\ntypedef.*//s;

    # Strip off license
    $desc =~ s#(?:/\*.*license.*?\*/)(.*)#$1#is;

    # Strip off copyright notice
    $desc =~ s#(?:/\*.*copyright.*?\*/)(.*)#$1#is;

    # Strip off emacs line
    $desc =~ s#(/\*.*tab-width.*?\*/)(.*)#$2#isg;

    # excise rcs crud
    $desc =~ s#Id: \Q$filename\E.*?Exp \$##g;

    # Yuck, nuke these silly comments in js/jsj /* ** */
    $desc =~ s#\n\s*/\*+[\s\*]+\*/\n#\n#sg;

    # Don't bother to continue if there aren't any comments here
    if(!($desc =~ m#/\*#)) {
	return("&nbsp;");
    }

    # Remove lines generated by jmc
    $desc =~ s#\n.*?Source date:.*\n#\n#;
    $desc =~ s#\n.*?Generated by jmc.*\n#\n#;

    # Extract the first comment
    $desc =~ s#(?:.*?/\*+)(.*?)(?:(?:\*+/.*)|(?:$))#$1#s;

    # Strip silly borders
    $desc =~ s#\n\s*[\*\=\-\s]+#\n#sg;

    # Strip beginning and trailing whitespace
    $desc =~ s/^\s+//;
    $desc =~ s/\s+$//;

    # Strip out file name
    $desc =~ s#$filename##i;

    # Strip By line
    $desc =~ s#By [^\n]*##;

    # Strip out dates
    $desc =~ s#\d{1,2}/\d{1,2}/\d\d\d\d##;
    $desc =~ s#\d{1,2}/\d{1,2}/\d\d##;
    $desc =~ s#\d{1,2} \w\w\w \d\d\d\d##;

    # Strip junk from the beginning
    $desc =~ s#[^\w]*##;

    # Extract the first paragraph
    $desc =~ s#(\n\s*?\n.*)##s;

    # If the description is too long then just use the first sentence
    # this will fail if no period was used.
    if (length($desc) > 200 ) {
        $desc =~ s#([^\.]+\.)\s.*#$1#s;
    }

    # If the description is still too long then assume it will look
    # like gobbledygook and give up
    if (length($desc) > 200 ) {
	return("&nbsp;");
    }

    # htmlify the comments, making links to symbols and files
    $desc = markupstring($desc, $Path->{'virt'});

    if ($desc) {
	return($desc);
    }else{
	return("\&nbsp\;");
    }
}


# dme: create a short description for a subdirectory in a directory listing
# If no description, return the string "\&nbsp\;" to keep the
# table looking pretty.
#
# In Mozilla, if the directory has a README file look in it for lines 
# like the ones used in source code: "directoryname --- A short description"
sub descexpand {
    # use global vars here because the expandtemplate subroutine makes
    # passing parameters impossible. Use $filename from source and
    # $Path from Common.pm
    my $filename = $main::filename;
    $filename .= '/' unless $filename =~ m{/$};
    my $linecount=0;
    local $desc= "";

    my $readmefile = $Path->{'real'}. $filename. 'README{.html,.htm,}';
    my @readmes = bsd_glob($readmefile);
    my $readme;
    foreach (@readmes) {
        next unless -f;
        $readme = $_;
        last;
    }
    if ($readme =~ /\.html?$/ && open(DESC, $readme)) {
        undef $/;
        $desc = <DESC>;
        $/ = "\n";
        close(DESC);

        # Make sure there is no <span> embedded in our string. If so 
        # then we've matched against the wrong /span and this string is junk
        # so we'll throw it away and refrain from writing a description.
        # Disallowing embedded spans theoretically removes some flexibility
        # but this seems to be a little used tag and doing this makes lxr 
        # a lot faster.
        if ($desc =~ /<SPAN CLASS=\"?LXRSHORTDESC\"?>(.*?)<\/SPAN>/is) {
            $short = $1;
            if (!($short =~ /\<span/is)) {
                return ($short);
            }
        }
    }

    $desc = ""; 
    my $rpath = $Path->{'real'};
    if (open(FILE, $rpath. $filename.'README') ||
        open(FILE, $rpath. $filename.'ReadMe')) {
	$path = $Path->{'virt'}.$filename;
	$path =~ s#/(.+)/#$1#;
        while(<FILE>){
            if($linecount++ > 10) {
                last;
            }elsif (/\s*\Q$path\E\s*-\s*-*\s*/i){
                $desc = (split(/\s*\Q$path\E\s*-\s*-*\s*/i))[1];
                if ($desc) {last};
            }elsif (/\s*\Q$filename\E\s*-\s*-*\s*/i){
                $desc = (split(/\s*\Q$filename\E\s*-\s*-*\s*/i))[1];
                if ($desc) {last};
            }elsif (/\Q$path\E\s*:\s*/i){
                $desc = (split(/ \Q$path\E\s*:\s*/i))[1];
                if ($desc) {last};
            }elsif (/\Q$filename\E\s*:\s*/i){
                $desc = (split(/ \Q$filename\E\s*:\s*/i))[1];
                if ($desc) {last};
            }
        }
        close(FILE);
    }
    $desc ||= descdebcontrol2($rpath, $Path->{'virt'}, $filename, 0);
    if ($filename =~ m%^debian/$%i) {
        $desc ||= descdebcontrol2($rpath, $Path->{'virt'}, './', 0);
    }
# git would be one of the following, but it doesn't work
# because the file {git}/description or {git}/.git/description
# doesn't seem to actually appear in checkouts...
=broken
    if (!$desc && open(FILE, $rpath.$filename.'description')) {
        $desc = <FILE>;
        close(FILE);
    }
=cut
    if (!$desc && open(FILE, $rpath.$filename.'README')) {
        $desc = <FILE>;
        close(FILE);
    }

    #strip trailing asterisks and "*/"
    $desc =~ s#\*/?\s*$##;

    if ($desc){
        #htmlify the comments making links to symbols and files
        $desc = markupstring($desc, $Path->{'virt'});

        return($desc);
    } else {
        return("\&nbsp\;");
    }
}

# dme: Print a descriptive blurb in directory listings between 
# the document heading and the table containing the actual listing.
#
# For Mozilla, we extract this information from the README file if
# it exists. If the file is short then just print the whole thing.
# For longer files print the first paragraph or so. As much as 
# possible make this work for randomly formatted files rather than 
# inventing strict rules which create gobbledygook when they're broken.
sub dirdesc {
    my ($path) = @_;
    my $rpath = $Path->{'real'};
    if ($rpath =~ m{_files/$}) {
        return if deschtmlfilesfolder($path);
    }
    if (-f $rpath."/README" ||
        -f $rpath."/ReadMe") {
        return if descreadme($path);
    }
    if (-f $rpath."/README.html") {
        return if descreadmehtml($path);
    }
    if (-f $rpath.'/DEBIAN/control' ||
        -f $rpath.'/debian/control') {
        return if descdebcontrol($path);
    }
}

sub deschtmlfilesfolder {
    my ($path) = @_;
    my $rpath = $Path->{'real'};
    my $base = $rpath;
    # chomp off the directory special bit
    $base =~ s{_files/}{};
    # try file.htm
    my $file = "$base.htm";
    unless (-f $file) {
      # try file.html
      $file .= 'l';
      return undef unless -f $file;
    }
    if (!(open(DESC, $file))) {
        return undef;
    }
    # we'll want the file name later
    $file =~ s{^.*/}{};
    my $line;
    my $result;
    while ($line = <DESC>) {
        if ($line =~ m{<title>(.*)</title>}i) {
            $result = $1;
            last;
        }
    }
    close(DESC);
    return undef unless $result;
    # we don't know if the content will be good or bad, it's easier to assume it's good for a bit
    # convert it to bad
    $result =~ s/\&lt;/</g;
    $result =~ s/\&gt;/>/g;
    $result =~ s/\&amp;/&/g;
    # and now know that all content is bad, and convert it to good
    $result =~ s/</&lt;/g;
    $result =~ s/>/&gt;/g;
    $result =~ s/\&/&amp;/g;
    print "<p><h2><a href='../$file'>$result</a></h2><p>";
    return 1;
}

sub descreadmehtml {
    my ($path, $readme) = @_;

    my $string = ""; 
    my $readmefile = $Path->{'real'}. 'README{.html,.htm}';
    my @readmes = bsd_glob($readmefile);
    foreach (@readmes) {
        next unless -f;
        $readme = $_;
        last;
    }
    if (!$readme || !open(DESC, $readme)) {
	return;
    }
    undef $/;
    $string = <DESC>;
    $/ = "\n";
    close(DESC);

    # if the README is 0 length then give up
    if (!$string) {
        return;
    }

    # check if there's a short desc nested inside the long desc. If not, do
    # a non-greedy search for a long desc. assume there are no other stray
    # spans within the description.
    if ($string =~ /<SPAN CLASS=\"?LXRLONGDESC\"?>(.*?<SPAN CLASS=\"?LXRSHORTDESC\"?>.*?<\/SPAN>.*?)<\/SPAN>/is) {
        $long = $1;
        if (!($long =~ m{<span.*?</span}is)) {
            $long .= "<P>\nSEE ALSO: ./README.html\n";
        }
    } elsif ($string =~ m{<SPAN CLASS=['"]?LXRLONGDESC['"]?>(.*?)</SPAN>}is) {
        $long = $1;
        if (!($long =~ m{<span}is)) {
            $long .= "<P>\nSEE ALSO: ./README.html\n";
        }
    } elsif ($string =~ m{<pre>(.*?)</pre>}is) {
        $long = $1;
        $long =~ s{^\s*$}{}g;
        $long =~ s/\n{2,}/\n/sg;
        $long =~ s{^((?:[^\n]*\n){1,10})(.*)$}{$1}s;
        $long = "<pre>" . $long;
	if ($2) {
            $readme =~ s{^.*/}{./};
            $long .= "<P>SEE ALSO: $readme\n";
        }
        $long .= "\n</pre>";
    }
    return 0 unless $long;
    print $long;
    return 1;
}

sub descreadme {
    my ($path) = @_;

    my $string = ""; 
#    $string =~ s#(</?([^>^\s]+[^>]*)>.*$)#($2~/B|A|IMG|FONT|BR|EM|I|TT/i)?$1:""#sg;
    my $n; 
    my $count;
    my $temp;

    my $maxlines = 20;  # If file is less than this then just print it all
    my $minlines = 5;   # Too small. Go back and add another paragraph.
    my $chopto = 10;    # Truncate long READMEs to this length

    if (!(open(DESC, $Path->{'real'}."/README") ||
          open(DESC, $Path->{'real'}."/ReadMe"))) {
	return;
        }

    undef $/;
    $string = <DESC>;
    $/ = "\n";
    close(DESC);

    # if the README is 0 length then give up
    if (!$string){
	return;
    }
    # strip the emacs tab line
    $string =~ s/.*tab-width:[ \t]*([0-9]+).*\n//;

    # strip the npl
    $string =~ s/.*The contents of this .* All Rights.*Reserved\.//s;

    # strip the short description from the beginning
    $path =~ s#/(.+)/#$1#;
    $string =~ s/.*\Q$path\E\/*\s+--- .*//;

    # strip away junk
    $string =~ s/#+\s*\n/\n/;
    $string =~ s/---+\s*\n/\n/g;
    $string =~ s/===+\s*\n/\n/g;

    # strip blank lines at beginning and end of file.
    $string =~ s/^\s*\n//gs;
    $string =~ s/\s*\n$//gs;
    chomp($string);
    $_ = $string;
    $count = tr/\n//;

    # If the file is small there's not much use splitting it up.
    # Just print it all
    if ($count > $maxlines) {
        # grab the first n paragraphs, with n decreasing until the
        # string is 10 lines or shorter or until we're down to 
	# one paragraph.
	$n = 6;
	$temp = $string;
	while ( ($count > $chopto) && ($n-- > 1) ) {
            $string =~ s/^((?:(?:[\S\t ]*?\n)+?[\t ]*\n){$n}?)(.*)/$1/s;
	    $_ = $string;
	    $string =~ s/\s*\n$//gs;
	    $count = tr/\n//;
	}

	# if we have too few lines then back up and grab another paragraph
	$_ = $string;
	$count = tr/\n//;
	if ($count < $minlines) {
	    $n = $n+1;
	    $temp =~ s/^((?:(?:[\S\t ]*?\n)+?[\t ]*\n){$n}?)(.*)/$1/s;
	    $string = $temp;
	}

	# if we have more than $maxlines then truncate to $chopto
	# and add an ellipsis. 
	if ($count > $maxlines) {
	    $string =~ s/^((?:[\S \t]*\n){$chopto}?)(.*)/$1/s;
	    chomp($string);
	    $string = $string . "\n...";
	} 
	
        # since not all of the README is displayed here,
        # add a link to it.
        chomp($string);
        if ($string =~ /SEE ALSO/) {
            $string = $string . ", README";
        } else {
            $string = $string . "\n\nSEE ALSO: ./README";
        }
    }

    $string = markupstring($string, $Path->{'virt'});
    $string = convertwhitespace($string, 1);
    $string =~ s/(SEE ALSO:)/\n$1/g;

    # strip blank lines at beginning and end of file again
    $string =~ s/^\s*\n//gs;
    $string =~ s/\s*\n$//gs;
    chomp($string);

    print("<pre>\n" . $string . "</pre>\n<p>\n");
}

sub descdebcontrol {
    my ($path) = @_;

    if (!(open(DESC, $Path->{'real'}.'/DEBIAN/control')) &&
        !(open(DESC, $Path->{'real'}.'/debian/control'))) {
        return;
    }

    my $line;
    while ($line = <DESC>) {
        if ($line =~ /^Description:\s*(.*)/) {
            $string = $1;
            last;
        }
        next if /^\w+:/;
        $string .= $line;
    }
    close(DESC);
    my $string = descdebcontrol2($Path->{'real'}, $Path->{'virt'}, './', 1); 
    chomp($string);
    $string = markupstring($string, $Path->{'virt'});
    $string = convertwhitespace($string, 1);
    # strip blank lines at beginning and end of file again
    $string =~ s/^\s*\n//gs;
    $string =~ s/\s*\n$//gs;
    chomp($string);

    print("<pre>" . $string . "</pre>\n<p>\n");
}

sub descdebcontrol2 {
    my $line;
    my $package;
    my %collection;
    my %descriptions;
    my ($rpath, $directory, $filename, $multiline) = @_;
    return '' unless open(FILE, $rpath.$filename.'DEBIAN/control') ||
                     open(FILE, $rpath.$filename.'debian/control');
    while ($filename eq '../') {
        $directory =~ m{^(.*)/+([^/]+)};
        ($directory, $filename) = ($1, $2.'/');
    }
    $directory =~ s{/+$}{};
    $directory =~ s{^.*/}{};
    while ($line = <FILE>) {
    restart:
        next unless $line =~ /^(Source|Package|Description):\s*(.*)\s*$/;
        my ($kind, $value) = ($1, $2);
        $collection{$kind} = $value;
	if ($kind eq 'Package') {
            if ($package =~ /^$|-d(?:ev|bg)$/) {
	        $package = $value;
            }
        }
        next unless $kind eq 'Description';
        if ($multiline) {
            my $accum;
            while ($line = <FILE>) {
                last unless $line =~ /\S/;
                last if $line =~ /^\S+:/;
                $accum .= $line;
            }
            $value = $accum if $accum =~ /\S/;
        }
        $descriptions{$collection{'Package'}} = $value;
        if ($multiline) {
            goto restart if $line =~ /^\w+:/;
        }
    }
    close(FILE);
    return $descriptions{$collection{Source}}
        || $descriptions{$directory}
        || $descriptions{$package};
}

sub readman {
    my $string = <DESC>;
    while ($string =~ /\\$/) {
        chop($string);
        $string .= <DESC>;
    }
    return $string;
}

sub descmanfile {
    my ($path) = @_;
    if (!(open(DESC, $path))) {
        return;
    }

    my ($line, $string);
    while ($line = readman()) {
        if ($line =~ m{^\.so (?:man\d+\.*/|)(.*)$}) {
            my $file = $1;
            my $dir = $path;
            $dir =~ s{/[^/]+$}{/$file};
            if (-f $dir) {
                close(DESC);
                return descmanfile($dir);
            } 
        }
        if ($line =~ /^\..*SH \S/) {
            $string = $line;
            $string = readman() while ($string =~ /^\.\\"/);
            $string = readman() while ($string =~ /^\./);
            $string = readman() while ($string =~ /^\.\\"/);
            last;
        }
        if ($line =~ /^\.\\" .SH (?:"|'|)NAME(?:"|'|)\s*$/) {
            (undef, $string) = (readman(), readman());
            last;
        }
        if ($line =~ /^(?:|.\\" ).SH (?:"|'|)(?:NAME|\x540D\x79F0)(?:"|'|)\s*$/) {
            $string = <DESC>;
            last;
        }
    }
    close(DESC);
    chomp($string);
    $string =~ s/\\//g;
    $string = markupstring($string, $Path->{'virt'});
    $string = convertwhitespace($string);
    # strip blank lines at beginning and end of file again
    $string =~ s/^\s*\n//gs;
    $string =~ s/\s*\n$//gs;
    chomp($string);

    return $string;
}

# dme: substitute carriage returns and spaces in original text
# for html equivalent so we don't need to use <pre> and can
# use variable width fonts but preserve the formatting
sub convertwhitespace {
    my ($string, $pre) = @_;
    my $p = $pre ? '' : '<p>';

    # handle ascii bulleted lists
    $string =~ s/<p>\n\s+o\s/<p>\n\&nbsp\;\&nbsp\;o /sg;
    $string =~ s/\n\s+o\s/&nbsp\;\n<br>\&nbsp\;\&nbsp\;o /sg;

    #find paragraph breaks and replace with <P>
    $string =~ s/\n\s*\n/$p\n/sg;

    return($string);
}

sub beginskip
{
    return '<![MXR[';
}

sub endskip
{
    return ']]>';
}

sub isForce {
my $force = $HTTP->{'param'}->{'force'};
$force = (defined $force && $force =~ /1|on|yes/ ? 1 : 0);
return $force;
}

sub isImage {
    return 0 if isForce();
my ($file, $ignore) = @_;
    return 0 unless (defined $ignore || $ENV{HTTP_ACCEPT} !~ 'text/html');
    return ($file =~ /\.(p?[jmp][pnm]e?g|gif|x[bp]m|svg|ico|ani|bmp)$/i);
}

sub isHTML {
    return 0 if isForce();
my $file = shift;
    return ($file =~ /\.html?$/);
}

sub isCSS {
    return 0 if isForce();
my $file = shift;
    return ($file =~ /stylesheet\.(css)$/) ||
          (($file =~ /\.(css)$/) && $ENV{HTTP_ACCEPT} !~ 'text/html');
}

sub getMimeType
{
    my ($file) = @_;
    my ($cat, $kind) = ('application', 'octet-stream');
    if (isHTML($file)) {
        $cat = 'text';
        $kind = 'html';
    } elsif (isCSS($file)) {
        $cat = 'text';
        $kind = 'css';
    } elsif (isImage($file)) {
        $kind = 'x-unknown';
        $cat = 'image';
        $kind = 'jpeg' if $file =~ /\.jpe?g$/i;
        $kind = 'pjepg' if $file =~ /\.pjpe?g$/i;
        $kind = 'gif' if $file =~ /\.gif$/i;
        $kind = 'png' if $file =~ /\.[jp]ng$/i;
        $kind = 'bitmap' if $file =~ /\.bmp$/i;
        $kind = 'svg+xml' if $file =~ /\.svg$/i;
        $kind = 'x-icon' if $file =~ /\.(ico|ani|xpm)$/i;
    }
    return "$cat/$kind";
}

sub localexpandtemplate
{
    my $template = shift;
    return LXR::Common::expandtemplate($template,
                          ('bonsaihost',        \&bonsaihost),
                          ('beginbonsai',       \&beginbonsai),
                          ('endbonsai',         \&endbonsai),
                          ('trachost',          \&trachost),
                          ('begintrac',         \&begintrac),
                          ('endtrac',           \&endtrac),
                          ('viewvctail',        \&viewvctail),
                          ('viewvchost',        \&viewvchost),
                          ('beginviewvc',       \&beginviewvc),
                          ('endviewvc',         \&endviewvc),
                          ('websvnhost',        \&websvnhost),
                          ('beginwebsvn',       \&beginwebsvn),
                          ('endwebsvn',         \&endwebsvn),
                          ('webhghost',         \&webhghost),
                          ('beginwebhg',        \&beginwebhg),
                          ('endwebhg',          \&endwebhg)
);
};

sub bonsaihost
{
    my $cvsrootfile = $Path->{'real'}.'/CVS/Root';
    my $bonsai_not_found = 'http://error.bonsai-not-found.tld';
    return $bonsai_not_found unless -f $cvsrootfile;
    return $bonsai_not_found unless open(CVSROOT,'<',$cvsrootfile);
    my $cvsroot = <CVSROOT>;
    close(CVSROOT);
    return 'http://bonsai-www.mozilla.org' if $cvsroot =~ m{mozilla\.org:/www};
    return 'http://bonsai-l10n.mozilla.org' if $cvsroot =~ m{mozilla\.org:/l10n};
    return 'http://bonsai.mozilla.org' if $cvsroot =~ /mozilla\.org:/;
    return 'http://cvs.gnome.org/bonsai' if $cvsroot =~ /gnome\.org:/;
    return 'http://bonsai.freedesktop.org' if $cvsroot =~ /freedesktop\.org:/;
    return $bonsai_not_found;
}

sub beginbonsai
{
    return &beginskip unless -f $Path->{'real'}.'/CVS/Entries';
    return &beginskip if $Path->{'svnrepo'};# =~ /songbird/;
    return '';
}

sub endbonsai
{
    return &endskip unless -f $Path->{'real'}.'/CVS/Entries';
    return &endskip if $Path->{'svnrepo'};# =~ /songbird/;
    return '';
}

sub trachost
{
    my $trac_not_found = 'http://error.trac-not-found.tld/ '.$Path->{'svnrepo'};
    return 'https://projects.maemo.org/trac' if $Path->{'svnrepo'} =~ /projects\.maemo\.org/;
    return 'http://publicsvn.songbirdnest.com/trac' if $Path->{'svnrepo'} =~ /songbird/;
    return 'http://trac.webkit.org/projects/webkit' if $Path->{'svnrepo'} =~ /webkit/;
    return 'http://svn-mirror.flock.com/trac/flock' if $Path->{'svnrepo'} =~ /flock/;
    return $trac_not_found;
}

sub begintrac
{
    return &beginskip unless $Path->{'svnrepo'} =~ /flock|songbird|webkit/;
    return '';
}

sub endtrac
{
    return &endskip unless $Path->{'svnrepo'} =~ /flock|songbird|webkit/;
    return '';
}

sub viewvctail
{
    if ($Path->{'svnrepo'} =~ m{\Qgarage.maemo.org/svn/\E([^/]+)}) {
        return "?root=$1";
    }
    return '?';
}

sub viewvchost
{
    return 'https://garage.maemo.org/plugins/scmsvn/viewcvs.php' if $Path->{'svnrepo'} =~ /garage/;
    return 'https://garage.maemo.org/plugins/scmsvn/viewcvs.php/' if $Path->{'svnrepo'} =~ /garage/;
    return 'https://stage.maemo.org/viewcvs.cgi/maemo/' if $Path->{'svnrepo'} =~ /stage/;
    return 'http://viewvc.svn.mozilla.org/vc' if $Path->{'svnrepo'} =~ /mozilla\.org/;
    return '';
}

sub beginviewvc
{
    return '' if $Path->{'svnrepo'} =~ /garage/;
    return &beginskip unless $Path->{'svnrepo'} =~ /stage|garage|mozilla\.org/;
    return '';
}

sub endviewvc
{
    return '' if $Path->{'svnrepo'} =~ /garage/;
    return &endskip unless $Path->{'svnrepo'} =~ /stage|garage|mozilla\.org/;
    return '';
}

sub websvnhost
{
    return '';
}

sub beginwebsvn
{
    return &beginskip unless 0;
    return '';
}

sub endwebsvn
{
    return &endskip unless 0;
    return '';
}

my %hgcache = ();
sub webhghost
{
    # needs to read /.hg/hgrc/ [paths] default
    return 'http://hg.mozilla.org';
}

sub checkhg
{
  my ($virt, $real) = ($Path->{'virt'}, $Path->{'real'});
  $real =~ s{/$}{};
  $virt =~ s{^/}{};
  my @dirs;# = split m%/%, $virt;
  while (!defined $hgcache{$real} && $real) {
print "<!-- check for .hg in $real -->
";
    if (-d $real.'/.hg') {
print "<!-- found .hg -->
";
      $hgcache{$real} = '0 '.$real . '/.hg/store/data';
      last;
    }
    $real =~ s{/([^/]*)$}{};
    unshift @dirs, $1;
  }
  if (defined $hgcache{$real}) {
    my $hgpath = $hgcache{$real};
    my $ll = 0 + $hgpath;
    $hgpath =~ s/^\d+ //;
print "<!-- $ll @ $hgpath -->
";
      $ll = 0 + $hgcache{$real};
print "<!-- hgcache{$real} [$#dirs,$ll]= ".$hgcache{$real}."
$hgpath -->
";
      while ($#dirs >= 0) {
        my $dir = '/' . (shift @dirs);
        $real .= $dir;
        $dir =~ s/([A-Z])/_$1/g;
        $dir = lc $dir;
        $hgpath .= $dir;
        ++$ll;
        $hgcache{$real} = -d $hgpath ? "$ll ". $hgpath : "0";
print "<!-- ann $real [$hgpath]: ".$hgcache{$real}." -->
";
      }
  }
  $real = $Path->{'real'};
  $real =~ s{/$}{};
  return $hgcache{$real};
}

sub beginwebhg
{
    return &beginskip unless checkhg($Path->{'virt'}, $Path->{'real'});
    return '';
}

sub endwebhg
{
    return &endskip unless checkhg($Path->{'virt'}, $Path->{'real'});
    return '';
}

1;
