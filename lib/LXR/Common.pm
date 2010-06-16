# $Id: Common.pm,v 1.31 2006/12/06 10:22:03 reed%reedloden.com Exp $

package LXR::Common;
use POSIX qw(log10);
use DB_File;
use lib '../..';
use Local;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw($Path &warning &fatal &abortall &fflush &urlargs
             &fileref &idref &htmlquote &freetextmarkup &markupfile
             &markspecials &statustextmarkup &markupstring
             markupstring2
             &checkhg
             &cleanquery
             &clean_mark
             &init &glimpse_init &makeheader &makefooter &expandtemplate
             &bigexpandtemplate &blamerefs
);

$wwwdebug = defined $ENV{'GATEWAY_INTERFACE'} ? 1 : 0;

$SIG{__WARN__} = 'warning';
$SIG{__DIE__}  = 'fatal';

my @allvariables_;
my %allvariable_;
my %alldefaults_;

my @term = (
  'atom',
  '\\\\.',
   '',
  'comment',
  '/\*',
   '\*/',
  'comment',
  '//',
   '(?:\r?\n|\r)',
  'string',
  '"',
   '"',
  'string',
  "'",
   "'",
  'verb',
  '\\b(?:for|do|while|else|if|throw|return)\\b',
   '[\s(;]',
  'verb',
  '\\b(?:true|false|void|unsigned|int|double|float|short|long|bool|char)\\b',
   '[\s();]',
  'verb',
'^(?:const|static|switch|case|default|break|next|continue|class|struct|union|enum)\\b',
   '\s',
  'include',
  '#\\s*include\\b',
   '[\r\n\b]',
  'include',
  '#\\s*import\\b',
   '[\r\n]',
);
=broken
  'include',
  '\\s*interface\\b,
  ';',
=cut

my @javaterm = @term;
push @javaterm, (
  'verb',
  '\\b(?:public|protected|private|package|implements|interface|extends|final|import|throws|abstract)\\b',
   '[\s]',
  'verb',
  '\\b(?:try|catch|finally)\\b',
   '[\s{(]',
  'verb',
  '\\b(?:new|delete|instanceof|null)\\b',
   '[\s()},]',
);

my @cterm = @term;
push @cterm, (
  'verb',
  '\\b(?:typedef)\\b',
   '[\s]',
  'verb',
'^#\\s*(?:if|(?:ifn?|un)def|else|elif|define|endif|pragma|warn(?:ing|)|error)\\b',
   '(?:\s|$)',
  'verb',
  '\\b(?:sizeof)\\b',
   '[\s(]',
  'verb',
  '\\b(?:register)\\b',
   '[\s();]',
);

my @cppterm = @cterm;
push @cppterm, (
  'verb',
  '\\b(?:template)\\b',
   '[\s<]',
  'verb',
  '\\b(?:inline|extern|explicit|new)\\b',
   '[\s]',
  'verb',
  '\\b(?:public|protected|private|interface|virtual|friend)\\b',
   '[\s:(]',
  'verb',
  '\\b(?:try|catch|finally|operator)\\b',
   '[\s{(]',
  'verb',
  '\\b(?:new|delete|null)\\b',
   '[\s()]',
);

my @jsterm = @javaterm;
push @jsterm, (
  'verb',
  '\\b(?:let|var|switch|for|yield|function|get|set|typeof)\\b',
   '[\\s(]',
  'verb',
  '\\b(?:this|prototype)\\b',
   '.',
  'verb',
  '\\bdefault\\s*:',
   '\\b',
  'verb',
  '\\bcase\\b',
   '\\b',
  'verb',
  '\\b(?:break|continue)\\s*;',
   '\\b',
);

my @pterm = (
  'atom',
  '\\\\.',
   '',
  'comment',
  '#',
   '(?:\r?\n|\r)',
  'comment',
  '^=(?:begin|pod|head)',
   '=cut',
  'string',
  "'",
   "'",
  'string',
  '"',
   '"',
  'string',
  '\\b(?:qq?|m)\|',
   '\|',
  'string',
  '\\b(?:qq?|m)#',
   '#',
  'string',
  '\\b(?:qq?|m)\(',
   '\)',
  'string',
  '\\b(?:qq?|m){',
   '}',
  'string',
  '\\b(?:qq?|m)<',
   '>',
  'verb',
  '\\bsub\\b',
   '\s',
#loop control
  'verb',
  '^\s*(?:new|for|foreach|while|else|elsif|if|unless|do|BEGIN|END)\b',
   '[ \(\{]',
#decl
  'verb',
  '^\s*(?:my|local|our)\b',
   '[ \(\{]',
#internal type
  'verb',
  '^\s*(?:defined|undef)\b',
   '[ \(\{]',
#comparitors
  'verb',
  '^\s*(?:eq|ne|ge|le|s|tr|lib)\b',
   '[\s\(\{]',
#native functions
  'verb',
  '^\s*(?:close|open|join|split|print|die|warn|push|pop|shift|unshift|delete|keys|tie|untie|length|scalar|ord|uc|lc|sprintf|qq|qw|q)\b',
   '[ \(\{]',
  'verb',
  '^\s*(?:exit|return|break|next|last|package)\\b',
   '[ ;\(]',
  'verb',
  '\\b(?:use|local|my)\\b',
   '[\s(]',
  'include',
  '\\b(?:require|import)\\b',
   ';',
  'use',
  '\\buse\\b',
   ';',
  'atom',
  '(?:[\$\@\&\%\=]?\w+)',
   '\\W',
);
=broken
  'comment',
    '^=cut',
   '^=back',
  'string',
  '^/',
   '/',
=cut

my @tterm = (
  'atom',
  '\\\\.',
   '',
  'comment',
  '\[\%#',
   '\%\]',
  'include',
  '\\bPROCESS\\b',
   '\%\]|\s$',
  'include',
  '\\bINCLUDE\\b',
   '\%\]|\s$',
  'use',
  '\\bUSE\\b',
   '\%\]',
  'string',
  '"',
   '"',
  'string',
  "'",
   "'",
);

my @poterm = (
  'atom',
  '\\\\.',
   '',
  'comment',
  '^#',
   '$',
  'verb',
  'msgstr',
   '"',
  'idprefix',
  'msgid\b.*"',
   '"',
);
=broken
  'verb',
  'msgstr',
   '"',
=cut

my @dtdterm = (
  'atom',
  '\\\\.',
   '',
  'comment',
  '<!--',
   '-->',
  'idprefix',
  '<!ENTITY\b',
   '>',
);

my @shterm = (
  'atom',
  '\\\\.',
   '',
  'comment',
  'dnl\b|#',
   '$',
  'verb',
  '(?:if|fi|case|esac|in|then|test|else|for|do|done)\\b',
   '\b',
);
=broken
  'string',
  '"',
   '"',
  'string',
  "'",
   "'",
  'string',
  '`',
   '`',
=cut

my @pyterm = (
  'atom',
  '\\\\.',
   '',
  'comment',
  '#',
   '$',
  'string',
  '"',
   '"',
  'include',
  '\\b(?:import)\\s+',
   '(?:\\bas\\b|$)',
  'include',
  '\\b(?:from)\\s+',
   '(?:$|\\bimport\\b)',
  'verb',
  '\\b(?:class|def|del|yield)\\b',
   '\W',
  'verb',
  '\\b(?:i[fns]|else|and|not|while|f?or|break|continue)\\b',
   '\W',
  'verb',
  '\\b(?:raise|try|except|finally|pass|return)\\b',
   '\W',
  'verb',
  '\\b(?:True|False|None)\\b',
   '',
);
=broken
  'string',
  "'",
   "'",
=cut

my @xmlterm = (
  'comment',
  '<!--',
   '-->',
  'idprefix',
  '<!ENTITY\b',
   '>',
  'idprefix',
  '<!DOCTYPE\b',
   '>',
  'string',
  '<!\[CDATA\[',
   '\]\]>',
  'verb',
  '</?\w+\b',
   '(?:\b|\s|>)',
  'verb',
  '\b(?:id|name|readonly)\b',
   '.',
);

my %alreadywarned = ();

sub warning {
  my ($wmsg, $wclass) = ($_[0], defined $_[1] ? $_[1] : '');
  return if $wclass && defined $alreadywarned{$wclass};
  print STDERR "[".scalar(localtime)."] warning: $wmsg\n";
  print "<h4 align=\"center\"><i>** Warning: ".htmlquote($wmsg)."</i></h4>\n" if $wwwdebug;
  $alreadywarned{$wclass} = 1 if $wclass;
}


sub fatal {
  my ($fmsg) = ($_[0]);
  print STDERR "[".scalar(localtime)."] fatal: $fmsg\n";
  print "<h4 align=\"center\"><i>** Fatal: ".htmlquote($fmsg)."</i></h4>\n" if $wwwdebug;
  exit(1);
}


sub abortall {
  print STDERR "[".scalar(localtime)."] abortall: $_[0]\n";
  if ($wwwdebug) {
    print(
"Content-Type: text/html

<html>
<head>
<title>Abort</title>
</head>
<body><h1>Abort!</h1>
<b><i>** Aborting: $_[0]</i></b>
</body>
</html>
");
  }
  exit(1);
}


sub fflush {
  $| = 1; print('');
}


sub urlargs {
  my @args = @_;
  my %args = ();
  my $val;

  if (scalar @args || scalar @allvariables_) {
    foreach (@args) {
      $args{$1} = $2 if /(\S+)=(\S*)/;
    }
    @args = ();

    foreach (@allvariables_) {
      $val = $args{$_} || $allvariable_{$_};
      push(@args, "$_=$val") unless ($val eq $alldefaults_{$_});
      delete($args{$_});
    }

    foreach (keys(%args)) {
      push(@args, "$_=$args{$_}");
    }
  }
  return $#args < 0 ? '' : '?'.join(';',@args);
}


sub fileref {
  my ($desc, $path, $line, @args) = @_;
$desc =~ s/\n//g;
$path =~ s/\n//g;
  #$path =~ s/\+/ /;

  # jwz: URL-quote any special characters.
  # endico: except plus. plus signs are normally used to represent spaces
  # but here we need to allow plus signs in file names for gtk+
  # hopefully this doesn't break anything else
  if ($path ne '') {
    # dealing w/ a url that has {},,@%-
    # http://timeless.justdave.net/mxr-test/chinook/source/defoma-0.11.7osso/%7Barch%7D/,,inode-sigs/gus@inodes.org--debian%25defoma--debian--1.0--patch-1
    if ($path =~ m|[^-a-zA-Z0-9.+,{}\@/_\r\n]|) {
      $path =~ s|([^-a-zA-Z0-9.+,{}\@/_\r\n])|sprintf("%%%02X", ord($1))|ge;
    }
    $path = "$Conf->{virtroot}/source$path";
  }
  $line = defined $line && $line > 0
        ? '#' . $line
        : '';
  unless (scalar @args || scalar @allvariables_) {
    return '<a href="'.$path.$line.'">'.$desc.'</a>';
  }
  return '<a href="'.$path.&urlargs(@args).$line.'">'.$desc.'</a>';
}


sub diffref {
  my ($desc, $path, $darg) = @_;

  ($darg,$dval) = $darg =~ /(.*?)=(.*)/;
  return "<a href=\"$Conf->{virtroot}/diff$path".
         &urlargs(($darg ? "diffvar=$darg" : ""),
                  ($dval ? "diffval=$dval" : ""),
                  @args).
         "\"\>$desc</a>";
}

my %id_cache = ();
my %id_cache2 = ();
my %id_cache3 = ();

sub maybe_idref {
  my ($desc, $filenum, $line) = @_;
  return $id_cache2{$desc} if defined $id_cache2{$desc};
  my $refed = $id_cache3{$desc};
  unless (defined $refed) {
    $id_cache3{$desc} = $refed = $xref{$desc} || '';
  }
  my $ident = !$refed
    && $desc =~ /([A-Z])(.*)|([a-z])(.*)/
    && $1
   ? (lc $1) . $2
   : ($3
     ? (uc $3) . $4
     : $desc);

  if ($ident ne $desc &&
      !defined $id_cache3{$ident} &&
      !($id_cache3{$ident} = $xref{$ident} || '')
      ) {
    return $id_cache2{$desc} = &atomref($ident);
  }
  my %ty = (('M', 'macro'),
            ('V', 'var'),
            ('f', 'proto'),
            ('F', 'function'),
            ('C', 'class'),
            ('c', 'class_forward'),
            ('T', 'type'),
            ('S', 'struct'),
            ('E', 'enum'),
            ('U', 'union'),
            ('R', 'reference'),
            ('I', 'interface'),
           );

  my $class = 'd';
  if (1) {
  } elsif (0) {
    my $id_line;
    if (defined $id_cache{$ident}) {
     $id_line = $id_cache{$ident};
    } else {
     $id_line = $id_cache{$ident} = $xref{$ident};
    }
    my @refs = split(/\t/,$id_line);
    if (1 || ($#refs < 100)) {
      foreach my $ref (@refs) {
        if ($ref =~ /^(.)(.*):(.*)/) {
          my ($refkind, $reffnum, $refline) = ($1, $2, $3);
# I have no explanation for this off by one problem.
          $refline++;
#$reffnum++;
#print "<!-- $ident ($line/$refline) [$reffnum/$filenum] [$refkind] -->";
          next unless $refline == $line;
          next unless $filenum == $reffnum;
#print "<!-- $ident ($line/$refline) [$reffnum/$filenum] $refkind /".(length $refkind)."/{".($ty{$refkind})."} -->";
#print "<!-- $ident $line $reffnum $refkind -->";
          $class = $ty{$refkind};
          last;
        }
      }
    }
  } elsif (1) {
    --$line;
    if ($xref{$ident} =~ /(?:^|\t)(.)$filenum:$line(?:$|\t)/) {
      my ($refkind) = ($1);
      $class = $ty{$refkind};
    }
  }
  my @args;
  push @args, 'scriptidly=1' if $desc ne $ident;
  return $id_cache2{$desc} = &idref($desc,$ident,$class,@args);
}

sub idref {
  my ($desc, $id, $class, @args) = @_;
  $class ||= 'd';
  unless ($id || scalar @args) {
    return '<a class="'.$class.'" href="'.$Conf->{virtroot}.
           '/ident'.
           '">'.$desc.'</a>';
  }
  return '<a class="'.$class.'" href="'.$Conf->{virtroot}.
         '/ident'.
         &urlargs(($id ? "i=$id" : ""),
                  @args).
         '">'.$desc.'</a>';
}


sub atomref {
  my ($atom) = @_;
  return "<span class='a'>$atom</span>";
}

sub http_wash {
  my $t = shift;
  # $t =~ s/\+/%2B/g;

  $t =~ s/\%2b/\%252b/gi;

  #endico: don't use plus signs to represent spaces as is the normal
  #case. we need to use them in file names for gtk+

  $t =~ s/\%([\da-f][\da-f])/pack("C", hex($1))/gie;

  # Paranoia check. Regexp-searches in Glimpse won't work.
  # if ($t =~ tr/;<>*|\`&$!#()[]{}:\'\"//) {

  return $t;
}


sub markspecials {
  $_[0] =~ s/([\0-\10])/\0$1/g;
  $_[0] =~ s/([\&\<\>])/\0$1/g;
  $_[0] =~ s{\0([\0-\10])}{"<tt>".ord($1)."</tt>"}ge;
}


sub htmlquote {
  $_[0] =~ s/\0&/&amp;/g;
  $_[0] =~ s/\0</&lt;/g;
  $_[0] =~ s/\0>/&gt;/g;
  $_[0] =~ s#\b(href=)("([^"]*)")\b#$1<a href="$3">$2</a>#gi;
}

sub freetextmarkup {
  my $tree = $Conf->{'treename'} ne '' ? '/' . $Conf->{'treename'} : '';
  my $virtf = $Path->{'virtf'};

  $_[0] =~ s#((?:ftp|https?|feed)://[^\s"'\)&<>\0]+)#<a href="$1">$1</a>#gi;
  $_[0] =~ s#(chrome)(://)(\w+)(/)(\w+)(/[^&\s]+|)(/[^/\s"'\)&<>]+)#<a href="$tree/search?string=$3&find=contents.rdf">$1$2</a><a href="$tree/search?string=$3&find=chrome\\.manifest">$3$4</a><a href="$tree/search?string=$3&find=chrome\\.manifest&filter=$5">$5</a><a href="$tree/find?string=$7&hint=$3$6$virtf">$6$7</a>#gi;
  $_[0] =~ s#(&amp;lt;(?:[Mm][Aa][Ii][Ll][Tt][Oo]:|)([^\s"']*?@[^\s"']*?)&amp;gt;)#<a href=\"mailto:$2\">$1</a>#g;
  $_[0] =~ s#(\((?:[Mm][Aa][Ii][Ll][Tt][Oo]:|)([^\s"']*?@[^\s"']*?)\))#<a href=\"mailto:$2\">$1</a>#g;
  $_[0] =~ s#(\0<(?:[Mm][Aa][Ii][Ll][Tt][Oo]:|)([^\s"']*?@[^\s"']*?)\0>)#<a href=\"mailto:$2\">$1</a>#g;
}

sub statustextmarkup {
  return unless $_[0] =~ /\@status/;
   $_[0] =~ s#(\@status\s+)(FROZEN|UNDER_REVIEW|DEPRECATED)\b#<span class="idl_$2">$1$2</span>#gi;
}

my $padding = 0;
sub csspadding {
  my ($y) = @_;
  my $style = '<style>';
  my $s = '';
  while ($y-- > 0) {
    $s .= ' ';
    $style .= ".d$y:before{content:'$s'} ";
  }
  return $style . '</style>';
}

my %marked_lines;

# The mark argument expects a specific format
# digit or (d1)-(d2)
# where digit is the line number to mark
#    and d1 & d2 are the optional beginning & ending of a range.
#    If d1 & d2 are omitted, the entire file is marked
sub clean_mark {
  my $mark = shift;
  $mark =~ s/,/,,/g;
  $mark =~ s/(^|,)[^,]*?-{2,}[^,]*?(,|$)/$1$2/g;
  $mark =~ s/(^|,)[^,]*?[^,0-9-][^,]*?(,|$)/$1$2/g;
  $mark =~ s/,{2,}/,/g;
  $mark =~ s/^,|,$//g;
  return $mark;
}

my @jscol_selected_lines;
sub build_mark_map {
  return unless (defined $HTTP->{'param'}->{'mark'});
  my $marks = clean_mark($HTTP->{'param'}->{'mark'});
  foreach my $mark (split ',', $marks) {
    if ($mark =~ m/^(\d*)-(\d*)$/) {
      my ($begin, $end) = ($1 || 1, $2);
      if ($end eq '' || $end < $begin) {
        $marked_lines{$begin} .= 'b';
        next;
      }
      if ($begin <= $end) {
        $marked_lines{$begin} .= 'b';
        $marked_lines{$end+1} .= 'e';
        next;
      }
      $mark = $begin;
    }
    $marked_lines{$mark} .= 's';
    push @jscol_selected_lines, $mark;
  }
}

my $lastclass;
my $nextrange = 1;
my $marker = 0;

sub endmark {
  --$marker;
  return '</div>';
}

my $colorwithjs = 0;

sub linetag {
  my ($file, $line) = @_;
#    my $virtfname = $virtp.$fname;
#$frag =~ s/\n/"\n".&linetag($virtfname, $line)/ge;
#    my $tag = '<a href="'.$_[0].'#L'.$_[1].
#              '" name="L'.$_[1].'">'.$_[1].' </a>';
  my $tag;
  if ($line >= $nextrange) {
    my $y = log10($line);
    my $x = $y | 0;
    $lastclass = "d$x";
    $nextrange *= 10;
    if ($x > $padding) {
      $tag = csspadding(++$padding) . $tag;
    }
  }
  my $class = $lastclass;
  if (defined $marked_lines{$line}) {
    my $mark = $marked_lines{$line};
    if ($mark =~ /[be]/) {
      while ($mark =~ s/e//) {
        $tag .= endmark();
      }
      while ($mark =~ s/b//) {
        $tag .= '<div class="m">';
        ++$marker;
      }
    }
    $class .= ' m' if $mark =~ 's';
  }
  return $tag if $colorwithjs;
  $tag .= &fileref($line, '', $line).' ';
  $tag =~ s/<a/<a class='l $class' name=$line/;
#    $_[1]++;
  return $tag;
}

# dme: Smaller version of the markupfile function meant for marking up
# the descriptions in source directory listings.
sub markupstring {
  my ($string, $virtp) = @_;

  # Mark special characters so they don't get processed just yet.
  markspecials($string);

  # Look for identifiers and create links with identifier search query.
  tie (%xref, "DB_File", $Conf->dbdir."/xref", O_RDONLY, 0664, $DB_HASH)
        || &warning("Cannot open xref database.", 'xref-db');
  $string =~ s#(^|\W|\s)([a-zA-Z_~][a-zA-Z0-9_]*)\b#
              $1.(is_linkworthy($2) ? &idref($2,$2) : $2)#ge;
  untie(%xref);

  # HTMLify the special characters we marked earlier,
  # but not the ones in the recently added xref html links.
  $string=~ s/\0&/&amp;/g;
  $string=~ s/\0</&lt;/g;
  $string=~ s/\0>/&gt;/g;

  # HTMLify email addresses and urls.
  $string =~ s#((ftp|https?|nntp|snews|news)://(\w|\w\.\w|\~|\-|\/|\#)+(?!\.\b))#<a href=\"$1\">$1</a>#g;
  # htmlify certain addresses which aren't surrounded by <>
  $string =~ s/([\w\-\_]*?\@(?:netscape\.com|mozilla\.(?:com|org)|gnome\.org|linux\.no))(?!&gt;)/<a href=\"mailto:$1\">$1<\/a>/g;
  $string =~ s/(&lt;)(.*?@.*?)(&gt;)/$1<a href=\"mailto:$2\">$2<\/a>$3/g;

  # HTMLify file names, assuming file is in the current directory.
  $string =~ s#\b(([\w\-_\/]+\.(cc?|hh?|cc|cpp?|mm?|idl|java|js|p[lm]))|README(?:\.(?:txt|html?)|))\b#<a href=\"$Conf->{virtroot}/source$virtp$1\">$1</a>#g;

  return $string;
}

# dme: Return true if string is in the identifier db and it seems like its
# use in the sentence is as an identifier and it isn't just some word that
# happens to have been used as a variable name somewhere. We don't want
# words like "of", "to" and "a" to get links. The string must be long
# enough, and  either contain "_" or have some letter other than the first
# which is capitalized
sub is_linkworthy {
  my ($string) = @_;

  if (($string =~ /....../) &&
      (($string =~ /_/) ||
        ($string =~ /.[A-Z]/)
        ) &&
        (defined($xref{$string}))
     ) {
    return 1;
  }
  return 0;
}

my $indexname;
my $sourceroot;
my @file_listing;
my $file_iterator;
my $file_length;
my $useglimpse = 1;

sub getnext_fileentry {
  my ($filematch) = @_;
  if ($useglimpse) {
    unless ($file_iterator) {
      $sourceroot = $sourceroot || $Conf->sourceroot;
      my @execparams = (
        $Conf->glimpsebin,
        '-H',
        $Conf->dbdir.'/.mxr',
        '-y',
        '-h',
        '-i',
        $filematch
      );
      my $execcmd = join ' ', @execparams;
      @file_listing = ();
      if (open(GLIMPSE, "$execcmd|")) {
        local $/;
        @file_listing = split /\n/, <GLIMPSE>;
        close GLIMPSE;
      }
    }
    return undef if $file_iterator > $#file_listing;
    my $fileentry = $file_listing[$file_iterator++];
    $fileentry =~ s/^$sourceroot//;
    return $fileentry;
  }
  unless (@file_listing)
  {
    my $indexname = $indexname || $Conf->dbdir."/.glimpse_filenames";
    $sourceroot = $sourceroot || $Conf->sourceroot;

    return undef unless open(FILELLISTING,$indexname);
    $file_length = <FILELLISTING>;
    $file_length =~ s/[\r\n]//g;
    @file_listing = ();
  }
  my $fileentry;
  my $filere = /$filematch/;
  if ($file_length == scalar @file_listing) {
    while ($file_iterator < $file_length) {
      $fileentry = $file_listing[$file_iterator++];
      if ($fileentry =~ $filere) {
        return $fileentry;
      }
    }
  }
  while (scalar @file_listing < $file_length) {
    $fileentry = <FILELLISTING>;
    chomp $fileentry;
    $fileentry =~ /^(?:$sourceroot|)(.*)\n?$/;
    $fileentry = $1;
    push @file_listing, $fileentry;
    if ($fileentry =~ $filere) {
      $file_iterator = scalar @file_listing;
      return $fileentry;
    }
    #return $fileentry;
  }
  $file_iterator = scalar @file_listing;
  if ($file_iterator == $file_length) {
    close FILELLISTING;
    return undef;
  }

  return undef;
}

sub filelookup {
  my ($filename,$bestguess,$prettyname)=@_;
  $prettyname = $filename unless defined $prettyname;
  return &fileref($prettyname, $bestguess) if -e $Conf->sourceroot.$bestguess;
  my $idlfile = $1 if ($filename =~ /(^.*)\.h$/);
  my $baseurl = $Conf->{virtroot}; # &baseurl;
  my ($pfile_ref,$gfile_ref,$ifile_ref,$jfile_ref,$kfile_ref,$loosefile,$basefile,$p,$g,$i,$j,$k);
  $filename =~ s|([(){}^\$.*?\&\@\\+])|\\$1|g;
  if ($filename =~ m|/|) {
    $basefile = $loosefile = $filename;
    $basefile =~ s|^.*/|/|g;
    $loosefile =~ s|/|/.*/|g;
  }
  $filename = '/' . $filename . '$';
  $file_iterator = 0;
  my $ifile = $idlfile || $filename;
  my $bgre = qr|/\Q$bestguess\E$|i;
  my $fere = qr|$filename|i;
  my $ire = qr|/\Q$idlfile.idl\E$|i;
  my $lre = qr|$loosefile|i;
  my $bre = qr|$basefile$|i;
  while ($fileentry = &getnext_fileentry($ifile)) {
    if ($fileentry =~ $bgre) {
      $pfile_ref=&fileref($prettyname, $fileentry, $hash);
      $p++;
    }
    if ($fileentry =~ $fere) {
      $gfile_ref=&fileref($prettyname, $fileentry, $hash);
      $g++;
    }
    if ($idlfile && $fileentry =~ $ire) {
      $ifile_ref=&fileref($prettyname, $fileentry, $hash);
      $i++;
    }
    if ($loosefile && $fileentry =~ $lre) {
      $jfile_ref=&fileref($prettyname, $fileentry, $hash);
      $j++;
    }
    if ($basefile && $fileentry =~ $bre) {
      $kfile_ref=&fileref($prettyname, $fileentry, $hash);
      $k++;
    }
    # Short circuiting:
    # If there's more than one idl file then just give a find for all stems
    # If there's an idl file and a header file then just give a find for all stems
    return "<a href='$baseurl/find?string=$idlfile'>$prettyname</a>" if ($p || $g || $i > 1) && $i;
  }
  return $pfile_ref if $p == 1;
  if  ($p == 0) {
    return $gfile_ref if $g == 1;
    if ($g == 0) {
      return $ifile_ref if $i == 1;
      if ($i == 0) {
        return $jfile_ref if $j == 1;
        return $kfile_ref if $j == 0 && $k == 1;
      }
    }
  }
  return "<a href='$baseurl/find?string=$idlfile$hash'>$prettyname</a>" if $i;
  return "<a href='$baseurl/find?string=$filename$hash'>$prettyname</a>" if $p || $g || !$loosefile;
  return "<a href='$baseurl/find?string=$loosefile$hash'>$prettyname</a>" if $j;
  return "<a href='$baseurl/find?string=$basefile$hash'>$prettyname</a>";
}

sub parsecvsentries {
  my ($entryrev,$entrybranch,$keywords);
  my ($entriespath, $entryname) = split m|/(?!.*/)|, $Path->{'realf'};
  if (open(CVSENTRIES, "$entriespath/CVS/Entries")) {
    while (<CVSENTRIES>) {
      next unless m|^/\Q$entryname\E/([^/]*)/[^/]*/([^/]*)/(.*)|;
      ($entryrev,$keywords,$entrybranch)=($1,$2,$3);
      last;
    }
    close(CVSENTRIES);
  }
  return ($entryrev,$entrybranch,$keywords);
}

sub getcvstag {
  my $entrybranch = 'HEAD';
  if (open(CVSTAG, " $Path->{'real'}/CVS/Tag")) {
    while (<CVSTAG>) {
      next unless /^T(.*)$/;
      $entrybranch=$1;
      last;
    }
    close(CVSTAG);
  }
  return $entrybranch;
}

sub get_mime_type {
  my $fname = shift;
  my $ext = $fname;
  $ext =~ s/^.*\.//;
  my $mime_types = '/etc/mime.types';
  return '' unless $ext ne '' || !-f $mime_types;
  my $override = '&ctype=';
  my $type;

  if (open(MIMETYPES,"<$mime_types")) {
    my $mime_entry;
    while (!defined $type && ($mime_entry = <MIMETYPES>)) {
      next unless $mime_entry =~ /^(\S+)\s.*\b$ext\b/;
      $type = $1;
    }
    close(MIMETYPES);
    return $override.$type;
  }
  return '';
}

my $code_print_limit = 16*1024; #   bytes of code at once
my $code_printed = 0;

sub print_code {
  my ($code, $outfun) = @_;
  if ($colorwithjs) {
    if ($code) {
      unless ($code_printed) {
        &$outfun ("<script>" .
          "addCode" .
          "(\"" );
      }
      # replace <span class="v"> with <V
      $code =~ s/<span class='([acvsi])'>/<\u$1/g;
      # replace end tags with ">", valid markup mandatory
      $code =~ s/<\/[^>]+>/>/g;
      my $ident_cgi = $Conf->{virtroot}.'/ident';
      # replace links to identifiers with <Didentifier>
      $code =~ s/<a class="d" href="$ident_cgi\?i=([^>"]+)">\1>/<D$1>/g;
      # replace link emphasis
      $code =~ s/<a href="([^>"]+)">\1>/<L$1>/g;
      # replace mailto emphasis
      $code =~ s/<a href="mailto:([^>"]+)">&lt;\1&gt;>/<M$1>/g;
      # escape special chars for JS strings
      $code =~ s/\\/\\\\/g;
      $code =~ s/"/\\"/g;
      $code =~ s/\n/\\n/g;
      &$outfun ($code);
      $code_printed += length $code;
      if ($code_printed >= $code_print_limit) {
        end_print_code ($outfun);
      }
    }
  }
  else
  {
    &$outfun ($code);
  }
}

sub end_print_code {
  if ($code_printed) {
    my $outfun = shift;
    &$outfun ("\");\n</script>");
    $code_printed = 0;
  }
}

sub markupfile {
  my ($INFILE, $Path, $fname, $outfun, $force) = @_;
  my $virtp = $Path->{'virt'};
  my $virtfname = $virtp.$fname;
  my @terms;
  my $filenum;
  $force = 0 unless defined $force;

  $line = 1;

  # A C/C++ file
  my $name = $fname =~ /(.*)\.in$/ ? $1 : $fname;
  if (defined $HTTP->{'param'}->{'handlename'}) {
    $name = $HTTP->{'param'}->{'handlename'};
  }
  if (defined $ENV{'HTTP_COOKIE'}) {
    my %cookie_jar = split('[;=] *',$ENV{'HTTP_COOKIE'});
    if($ENV{'HTTP_COOKIE'} =~ /handlename/) {
      $name = $cookie_jar{'handlename'} if defined $cookie_jar{'handlename'};
    }
    if ($ENV{'HTTP_COOKIE'} =~ /colorwithjs/) {
      $colorwithjs = 0 + $cookie_jar{'colorwithjs'} if defined $cookie_jar{'colorwithjs'};
    }
  }
  if (defined $HTTP->{'param'}->{'colorwithjs'}) {
    $colorwithjs = 0 + $HTTP->{'param'}->{'colorwithjs'};
  }

  build_mark_map();
  if ($colorwithjs) {
    &$outfun ("<script>window.use_js_coloration = true;\n");
    if (@jscol_selected_lines) {
        &$outfun ("window.marked_lines=[" . join (',', @jscol_selected_lines) . "];\n");
    }
    &$outfun ("window.ident_cgi='".$Conf->{virtroot}."/ident';\n");
    &$outfun ("</script>");
    &$outfun ("<noscript>Script has been disabled, please reload the page to see the scriptless version.</noscript>");
  }

  # estimate padding
  my $size = (stat($Path->{'realf'}))[7];
  $size = (log10($size / 40) | 0) + 1 if $size;
  $padding = $size < 3 ? 3 : $size;
  &$outfun (csspadding ($padding));

  &$outfun ("<span id='the-code'>");

  if ($name =~ /\.(?:java|idl)$/i) {
    @terms = @javaterm;
  } elsif ($name =~ /\.(?:hh?|s|cpp?|c[cs]?|mm?|pch\+?\+?|fin|tbl)$/i) { # Duplicated in genxref.
    @terms = @cppterm;
  } elsif ($name =~ /\.(?:jsm?)(?:\.in|)$/) {
    @terms = @jsterm;
  } elsif ($name =~ /\.(?:p[lm]|cgi|pod|t|tt2)$/i) {
    @terms = @pterm;
  } elsif ($name =~ /\.(?:tm?pl)$/) {
    @terms = @tterm;
  } elsif ($name =~ /\.(?:po)$/) {
    @terms = @poterm;
  } elsif ($name =~ /\.(?:dtd)$/) {
    @terms = @dtdterm;
  } elsif ($name =~ /(configure|\.sh)$/) {
    @terms = @shterm;
  } elsif ($name =~ /\.(?:py)$/) {
    @terms = @pyterm;
  } elsif ($name =~ /\.(?:xml)$/) {
    @terms = @xmlterm;
  } else {
    open HEAD_HANDLE, $fname;
    my $file_head = <HEAD_HANDLE>;
    @terms = @pterm if $file_head =~ /^#!.*perl/;
    @terms = @shterm if $file_head =~ /^dnl( |$)/;
    close HEAD_HANDLE;
  }
  if (@terms) {
    &SimpleParse::init($INFILE, @terms);

    my $hash_params = new DB_File::HASHINFO;
    $hash_params->{'cachesize'} = 30000;
    tie (%xref, "DB_File", $Conf->dbdir."/xref", O_RDONLY, 0664, $hash_params)
        || &warning("Cannot open xref database.", 'xref-db');
    if (tie(%fileidx, "DB_File", $Conf->dbdir."/fileidx",
            O_RDONLY, undef, $hash_params)) {
      foreach my $key (keys %fileidx) {
        my $val = $fileidx{$key};
        if (($virtfname eq $val) ||
            ($virtfname eq '/'.$val)) {
          $filenum = $key, last;
        }
      }
      untie(%fileidx);
    } else {
      my $tree = $Conf->{'treename'} ne '' ? ' for "'.$Conf->{'treename'}.'"' : '';
      &warning('Cross reference database is missing its file list'.$tree.'; please complain to the webmaster [cite: fileidx]');
    }

    &print_code (&linetag($virtfname, $line++), $outfun);

    ($btype, $frag) = &SimpleParse::nextfrag;

    while (defined($frag)) {
#print "<!--$btype-->" if @terms eq @pterm;
      &markspecials($frag);
      if ($btype eq 'verb') {
        $frag = "<span class='v'>$frag</span>";
      } elsif ($btype eq 'comment') {
        # Comment
        # Convert mail addresses to mailto:
        &freetextmarkup($frag);
        &statustextmarkup($frag);
        $frag = "<span class='c'>$frag</span>";
        $frag =~ s#\r?\n|\r#</span>\n<span class='c'>#g;
      } elsif ($btype eq 'string') {
        # String
        $frag = "<span class='s'>$frag</span>";
      } elsif ($btype eq 'idprefix') {
        if ($frag =~ s#(\w+)(\W+)([\w_]*)#<span class='v'>$1</span>$2<a href="$Conf->{virtroot}/search?string=$3">$3</a>#) {

          #print "<!-- -->";
        }
      } elsif ($btype eq 'include') {
        # Include directive
        if ($frag =~ s#\0(<)(.*?)\0(>)#
            '&lt;'.
            &filelookup($2, $Conf->mappath($Conf->incprefix.'/'.$2)).
            '&gt;'#e) {
        } else {
          my ($inc_head, $inc_file, $inc_tail, $prettyfile);
          if ($frag =~ s#(\s*[\"\'])(.*?)([\"\'])#
                         ($1)."\0$2\0".($3)#e) {
            ($inc_head, $inc_file, $inc_tail, $prettyfile) = ($1, $2, $3, $2);
          } elsif ($frag =~ s#((?:\s*require|)\s+)([^\s;]+)#
                              ($1)."\0$2\0"#e) {
            ($inc_head, $inc_file, $inc_tail, $prettyfile) = ($1, $2, undef, $2);
          }
          unless (length $inc_tail) {
            if (@terms == @plterm) {
              $inc_file =~ s|::|/|g;
              $inc_file .= '.pm';
            } elsif (@terms == @pyterm) {
              $inc_file =~ s|\.|/|g;
              $inc_file .= '.py';
            }
          }
          $frag =~ s#\0.*?\0#
                     &filelookup($inc_file, $virtp.$inc_file,$prettyfile)#e;
        }
        $frag =~ s/('[^'+]*)\+(.*?')/$1\%2b$2/ while $frag =~ /(?:'[^'+]*)\+(?:.*?')/;
        $frag =~ s|(#?\s*[^\s"'<]+)|<span class='i'>$1</span>|;
      } elsif ($btype eq 'use') {
        # perl use directive
        $frag =~ s#(use|USE)(\s+)([^\s;]*)#<span class='i'>$1</span>$2$3#;
        my $module = $3;
        my $modulefile = "$module.pm";
        $modulefile =~ s|::|/|g;
        $module = (&filelookup($modulefile, $modulefile, $module));
        $frag =~ s|(</span>\s+)([^\s;]*)|$1$module|;
      } elsif ($btype eq 'perldoc') {
        # PerlDoc
        $frag =~ s#(=head.\s+([^\s(]*)(?:([(]).*?([)])|))#<a name="$2$3$4">$1</a>#g;
        $frag =~ s#(I\0?<)(.*?)(\0?>)#$1<i>$2</i>$3#g;
        $frag =~ s#(C\0<)(.*?)(\0>)#$1<code><u>$2</u></code>$3#g;
        $frag =~ s#(E\0<lt\0>)([^\0]*?@[^\0]*)(E\0<gt\0>)#$1<a href="mailto:$2">$2</a>$3#g;
        $frag =~ s%(L\0)(<)(\w+?://[^\0]*?)(\0>)%$1\0$2<a href="$3">$3</a>$4%g;
        $frag =~ s%(L\0)(<)([^(\0]*?\(\))(\0>)%$1\0$2<a href="#$3">$3</a>$4%g;
        my ($ref_name, $ref_file, $ref_hash, $prettyfile);
        while ($frag =~ s%(L\0)(<)(([^\|#\0]*)(?:\|(([^#\0]*)(#[^\0]*?|))|))(\0)(>)%
                       "$1\0$2\0!$3\0!$8_$9"%e) {
            ($ref_name, $ref_file, $ref_hash, $prettyfile) = ($4, $6 || $4, $7, $3);
            $ref_file =~ s|::|/|g;
            $ref_file .= '.pm';
            $frag =~ s#\0!.*?\0!#
                       &filelookup($ref_file, $virtp.$ref_file, $prettyfile, $ref_hash)#e;
        }
        $frag =~ s%L\0\0<(.*?)\0_>%L\0<$1\0>%g;
        $frag =~ s%L\0\0<%L\0<%g;
        $frag = "<span class='perldoc c'>$frag</span>";
        $frag =~ s#(?:\r?\n|\r)#</span>\n<span class='perldoc c'>#g;
      } else {
        # Code
        $frag =~ s#(^|[^a-zA-Z_\#0-9])([a-zA-Z_][a-zA-Z0-9_]*)\b#
                    $1.($id_cache3{$2} || ($id_cache3{$2} = ($xref{$2} || '')) ? &maybe_idref($2, $filenum, $line) : &atomref($2))#ge;
      }

      &htmlquote($frag);
      $frag =~ s/(?:\r?\n|\r)/"\n".&linetag($virtfname, $line++)/ge;
      &print_code ($frag, $outfun);

      ($btype, $frag) = &SimpleParse::nextfrag;
    }
=skip
    &$outfun("</pre>\n");
=cut
    untie(%xref);

  } elsif (Local::isImage($fname, 1)) {

    &$outfun("</pre>");
    &$outfun("<ul><table><tr><th valign=middle><b>Image: </b></th>");
    &$outfun("<td valign=middle>");

    my $img = 'img';
    my $ctype;
    my $extra;
    if ($fname =~ /\.svg$/) {
      $ctype = 'image/svg+xml';
      $extra = "&ctype=$ctype";
      $img = "embed type='$ctype'";
    }
    &$outfun("<$img src=\"$Conf->{virtroot}/source".$virtfname.
             &urlargs("raw=1").$extra."\" border=\"0\" alt=\"$fname\">");

    &$outfun("</tr></td></table></ul><pre>");

  } elsif ($fname eq 'CREDITS') {
    while (<$INFILE>) {
      &SimpleParse::untabify($_);
      &markspecials($_);
      &htmlquote($_);
      s/^N:\s+(.*)/<strong>$1<\/strong>/gm;
      s/^(E:\s+)(\S+@\S+)/$1<a href=\"mailto:$2\">$2<\/a>/gm;
      s/^(W:\s+)(.*)/$1<a href=\"$2\">$2<\/a>/gm;
=skip
      &$outfun("<a name=\"L$.\"><\/a>".$_);
=cut
      &$outfun(&linetag($virtfname, $.).$_);
    }
  } else {
    $colorwithjs = 0;
    my $is_binary = -1;
    my $keywords;
    (undef,undef,$keywords) = &parsecvsentries;
    READFILE:
    my $first_line = <$INFILE>;

    $_ = $first_line;
    if ($keywords =~ /-kb/) {
      $is_binary = 1;
      print "CVS Says this is binary<br>";
    } elsif ( m/^\#!/ ) {
      # it's a script
      $is_binary = 0;
    } elsif ( m/-\*-.*mode:/i ) {
      # has an emacs mode spec
      $is_binary = 0;
    } elsif (length($_) > 132) {
      # no linebreaks
      my $macline = $_;
      if ($is_binary == -1 && $macline =~ s/\r//g > 5) {
        # mac linebreaks?
        # restart at the beginning of the file
        seek $INFILE, 0, 0;
        # reset the line counter to the beginning
        $. = 0;
        # set the input record to macnewline
        $/ = "\r";
        # make sure not to loop infinitely
        $is_binary = -2;
        goto READFILE;
      }
      $is_binary = 1;
    } elsif ( m/[\000-\010\013\014\016-\037\200-\237]/ ) {
      # ctrl or ctrl+
      $is_binary = 1;
    } else {
      # no idea, but assume text.
      $is_binary = 0;
    }

    if ( $is_binary && !$force ) {

      &$outfun("</pre>");
      &$outfun("<ul><b>Binary File: ");

      # jwz: URL-quote any special characters.
      my $uname = $fname;
      $uname =~ s|([^-a-zA-Z0-9.\@/_\r\n])|sprintf("%%%02X", ord($1))|ge;
      my $ctype = get_mime_type($fname);

      &$outfun("<a href=\"$Conf->{virtroot}/source".$virtp.$uname.
               &urlargs("raw=1").$ctype."\">");
      &$outfun("$fname</a></b>");
      &$outfun("</ul><pre>");

    } else {
      $_ = $first_line;
      do {
        &SimpleParse::untabify($_);
        &markspecials($_);
        &htmlquote($_);
        &freetextmarkup($_);
=skip
        &$outfun("<a name=\"L$.\"><\/a>".$_);
=cut
        &$outfun(&linetag($virtfname, $.).$_);
      } while (<$INFILE>);
      print endmark() while $marker;
    }
  }

  &print_code (endmark(), $outfun) while $marker;    # just in case
  end_print_code ($outfun);
  &$outfun ("</span>");    # end of <span id='the-code'>
}


sub fixpaths {
  my $virtf = '/'.shift;
  return unless defined $Conf->sourceroot;
  $Path->{'root'} = $Conf->sourceroot;

  while ($virtf =~ s#/[^/]+/\.\./#/#g) {
  }
  $virtf =~ s#/\.\./#/#g;

  $virtf .= '/' if (-d $Path->{'root'}.$virtf);
  $virtf =~ s#//+#/#g;

  my ($virt, $file) = $virtf =~ m{^(.*/)([^/]*)$};

  ($Path->{'virtf'}, $Path->{'virt'}, $Path->{'file'}) = ($virtf, $virt, $file);

  my $real = $Path->{'real'} = $Path->{'root'}.$virt;
  my $realf = $Path->{'realf'} = $Path->{'root'}.$virtf;

  my $svndirprop = $real . ".svn/dir-wcprops";
  if (-f $svndirprop) {
    if (open (SVN, $svndirprop))
    {
      my $svnpath;
      $svnpath = <SVN> while $svnpath !~ /^V \d+$/;
      $svnpath = <SVN>;
      $svnpath =~ m|^/svn/([^/]*)/!svn/ver/\d+/(.*)|;
      my $svntree = $1;
      $svnpath = $2;
      $svnpath =~ s/[\n\r]//g;
      $svntree =~ s{^(.)}{/$1};

      $Path->{'svnvirt'} = $svnpath;
      $Path->{'svntree'} = $svntree;
      close SVN;
    }
  }

  my $svnentries = $real . ".svn/entries";
  if (-f $svnentries) {
    if (open (SVN, $svnentries))
    {
      my $svnrepo;
=svn_ver_8
8

dir
379
https://garage.maemo.org/svn/browser/mozilla/trunk/microb-eal/src
https://garage.maemo.org/svn/browser
=cut
=svn_ver_9
9

dir
1657
http://src.chromium.org/svn/trunk/src/chrome/browser
http://src.chromium.org/svn
=cut
      my $svnpath = $Path->{'svnvirt'} || undef;
      my $svnurl;
      my $svnhead = <SVN>;
      if ($svnhead =~ /<\?xml/) {
        while ($svnrepo = <SVN>) {
          unless ($svnpath) {
            if ($svnrepo =~ /url="(.*)"/) {
              $Path->{'svnrepo'} = $svnurl = $1;
            }
          }
          if ($svnrepo =~ /repos="(.*)"/) {
            $Path->{'svnrepo'} = $1;
            $svnrepo = $1 . '/';
            last if $svnpath;
            if ($svnurl) {
              my $i = rindex $svnurl, $svnrepo;
              if ($i > -1) {
                $svnpath = substr $svnurl, $i + length $svnrepo;
                $svnpath =~ s{^(.)}{/$1};
                $Path->{'svnvirt'} = $svnpath;
                last;
              }
            }
          }
        }
      } elsif ($svnhead =~ /^\d/) {
        local $/ = "\f";
        my $svnentry = <SVN>;
        my $svnpath;
        (undef, undef, undef, $svnurl, $svnrepo) = split /\n/, $svnentry;
        my $i = rindex $svnurl, $svnrepo;
        if ($i > -1) {
          $svnpath = substr $svnurl, $i + length $svnrepo;
        }
        $Path->{'svnrepo'} = $svnurl;
        $Path->{'svnvirt'} = $svnpath;
      }
      close SVN;
    }
  }
  if ($Path->{'svnvirt'} && $Path->{'svnvirt'} !~ m{^/}) {
    $Path->{'svnvirt'} = '/' . $Path->{'svnvirt'};
  }

  @pathelem = $Path->{'virtf'} =~ /([^\/]+$|[^\/]+\/)/g;

  $fpath = '';
  foreach (@pathelem) {
    $fpath .= $_;
    push(@addrelem, $fpath);
  }
  my $fix = '';
  if (defined $Conf->prefix) {
    $fix = $Conf->prefix.'/';
    unshift(@pathelem, $fix);
    unshift(@addrelem, "");
    $fix =~ s#[^/]##g;
    $fix =~ s#/#../#g;
  }
  unshift(@pathelem, $Conf->sourcerootname.'/');
  unshift(@addrelem, $fix);

  my $xref = '';
  foreach (1..$#pathelem) {
    if (defined($addrelem[$_])) {

      # jwz: put a space after each / in the banner so that it's possible
      # for the pathnames to wrap.  The <wbr> tag ought to do this, but
      # it is ignored when sizing table cells, so we have to use a real
      # space.  It's somewhat ugly to have these spaces be visible, but
      # not as ugly as getting a horizontal scrollbar...
      #
      $xref .= &fileref($pathelem[$_], "/$addrelem[$_]") . " ";
    } else {
      $xref .= $pathelem[$_];
    }
  }
  $xref =~ s#/</a>#</a>/#gi;
  $Path->{'xref'} = $xref;
}

sub env_or {
  my ($name, $default) = @_;
  return defined $ENV{$name} ? $ENV{$name} : $default;
}

sub set_this_url {
  # HTTPS
  my $default_port = env_or('HTTPS', 0) ? 443 : 80;
  my $env_port = env_or('SERVER_PORT', 80);
  my $port = $default_port eq $env_port ? '' : ':'. $env_port;
  my $proto = $default_port == 443 ? 'https://' : 'http://';
  my $query = env_or('QUERY_STRING', '');
  $query = '?' . $query if $query ne '';

  $HTTP->{'this_url'} =
    &http_wash(
      join('',
           $proto,
           env_or('SERVER_NAME', 'localhost'),
           $port,
           env_or('SCRIPT_NAME', 'unknown_script'),
           env_or('PATH_INFO', ''),
           $query)
    );
}

sub glimpse_init {
  set_this_url();
  my @a;

  my $query = env_or('QUERY_STRING', '');
  foreach ($query =~ /([^;&=]+)(?:=([^;&]+)|)/g) {
    push(@a, &http_wash($_));
  }
  $HTTP->{'param'} = {@a};
  my $head = init_all();

  if ($query =~ s/\&regexp=on//) {
    $Conf->{'regexp'} = 'on';
  } else {
    $query =~ s/\&regexp=off//;
    $Conf->{'regexp'} = 'off';
  }
  #$ENV{'QUERY_STRING'} = $query;

  return ($Conf, $HTTP, $Path, $head);
}


sub init {
  set_this_url();
  my @a;
  my $query = env_or('QUERY_STRING', '');
  foreach ($query =~ /([^;&=]+)(?:=([^;&]+)|)/g) {
    push(@a, &http_wash($_));
  }
  $HTTP->{'param'} = {@a};
  my $head = init_all();
  return ($Conf, $HTTP, $Path, $head);
}

sub pretty_date {
  my $time = shift;
  my @t = gmtime($time);
  my ($sec, $min, $hour, $mday, $mon, $year,$wday) = @t;
  my @days = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
  my @months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
  $year += 1900;
  $wday = $days[$wday];
  $mon = $months[$mon];
  return sprintf("%s, %02d %s %d %02d:%02d:%02d GMT",
                 $wday, $mday, $mon, $year, $hour, $min, $sec);
}

sub init_all {
  my ($argv_0) = @_;

  $HTTP->{'path_info'} = &http_wash(env_or('PATH_INFO', ''));
  $HTTP->{'http_user_agent'} = env_or('HTTP_USER_AGENT', '');
  $HTTP->{'param'}->{'v'} ||= $HTTP->{'param'}->{'version'};
  $HTTP->{'param'}->{'a'} ||= $HTTP->{'param'}->{'arch'};
  $HTTP->{'param'}->{'i'} ||= $HTTP->{'param'}->{'identifier'};


  $identifier = $HTTP->{'param'}->{'i'};
  $Conf = new LXR::Config;

  @allvariables_ = $Conf->allvariables;
  foreach (@allvariables_) {
    $allvariable_{$_} = $Conf->variable($_);
    $alldefaults_{$_} = $Conf->vardefault($_);
    $Conf->variable($_, $HTTP->{'param'}->{$_}) if $HTTP->{'param'}->{$_};
  }

  my $path = $HTTP->{'path_info'} || '';
  $path = $HTTP->{'param'}->{'file'} || '' unless $path;
  &fixpaths($path);

  my $head = '';
  my $ctype = 'text/html';

  if ($HTTP->{'http_user_agent'} =~ m{^mercurial/}) {
    $HTTP->{'param'}->{'raw'} = 1;
    $HTTP->{'param'}->{'ctype'} = 'application/octet-stream';
  }

  if (defined($HTTP->{'param'}->{'raw'})) {
    $ctype = $HTTP->{'param'}->{'ctype'};
    $ctype = ($ctype =~ m|([\w\d\.;/+-]+)|) ? $1 : undef;
  }

  my $baseurl = $Conf->{baseurl};
  my $localurl = $baseurl . '/source' . env_or('PATH_INFO', '/');
  $localurl =~ m{(^.*/)/*[^/]+/*(?:|\?.*)$};
  my $parenturl = $1;
  $head .=
'Link: <' . $baseurl . '>; rel="Index"; title="' . $Conf->{'treename'} .'"
Link: <' . $baseurl . '/ident>; rel="Glossary"; title="Identifier search"
Link: <' . $baseurl . '/search>; rel="Search"; title="Text search"
Link: <' . $baseurl . '/find>; rel="Contents"; title="Find file"
Link: <' . $parenturl . '>; rel="Up"; title="Parent"
';

  $head .= "Content-Type: $ctype\n" if defined $ctype;

  #
  # Print out a Last-Modified date that is the larger of: the
  # underlying file that we are presenting; and the "source" script
  # itself (passed in as an argument to this function.)  If we can't
  # stat either of them, don't print out a L-M header.  (Note that this
  # stats lxr/source but not lxr/lib/LXR/Common.pm.  Oh well, I can
  # live with that I guess...)    -- jwz, 16-Jun-98
  #
  my $file1 = $Path->{'realf'};
  my $file2 = $argv_0;

  # make sure the thing we call stat with doesn't end in /.
  if ($file1) { $file1 =~ s{/$}{}; }
  if ($file2) { $file2 =~ s{/$}{}; }

  my $time1 = 0, $time2 = 0;
  if ($file1 && -r $file1) { $time1 = (stat($file1))[9]; }
  if ($file2) { $time2 = (stat($file2))[9]; }

  my $mod_time = ($time1 > $time2 ? $time1 : $time2);
  if ($mod_time > 0) {
    # Last-Modified: Wed, 10 Dec 1997 00:55:32 GMT
    $head .= ("Last-Modified: ".(pretty_date($mod_time))."\n");
    # Expires: Thu, 11 Dec 1997 00:55:32 GMT
    $head .= ("Expires: ".(pretty_date(time+1200))."\n");
  }
  # remove cookie so that if JS is disabled, reloading the page is enough to get back to "old" JS-less behaviour
  $head .= "Set-Cookie: colorwithjs=; path=/; expires= Sat, 01-Jan-2000 00:00:00 GMT\n";

  return ($Conf, $HTTP, $Path, $head);
}


sub expandtemplate {
  my ($templ, %expfunc) = @_;
  my ($expfun, $exppar);

  while ($templ =~ s/(\{[^\{\}]*)\{([^\{\}]*)\}/$1\01$2\02/s) {}

  $templ =~ s/(\$(\w+)(\{([^\}]*)\}|))/{
    if (defined($expfun = $expfunc{$2})) {
      if ($3 eq '') {
        &$expfun(undef, @expfunc);
      } else {
        $exppar = $4;
        $exppar =~ s#\01#\{#gs;
        $exppar =~ s#\02#\}#gs;
        &$expfun($exppar, @expfunc);
      }
    } else {
      $1;
    }
  }/ges;

  $templ =~ s/\01/\{/gs;
  $templ =~ s/\02/\}/gs;
  $templ =~ s/<!\[MXR\[.*?\]\]>//gs;
  return $templ;
}


# What follows is a pretty hairy way of expanding nested templates.
# State information is passed via localized variables.

# The first one is simple, the "banner" template is empty, so we
# simply return an appropriate value.
sub bannerexpand {
  if ($who eq 'source' || $who eq 'sourcedir' || $who eq 'diff') {
    return $Path->{'xref'};
  };
  return '';
}

sub filepathname {
  return url_quote($Path->{'virtf'});
}

sub cvsentriesexpand {
  my ($entryrev, $entrybranch);
  local $,=" | ";
  my ($entriespath, $entryname) = split m|/(?!.*/)|, $Path->{'realf'};
  if (open(CVSENTRIES, "$entriespath/CVS/Entries")) {
    while (<CVSENTRIES>) {
      next unless m|^/\Q$entryname\E/([^/]*)/[^/]*/[^/]*/(.*)|;
      ($entryrev,$entrybranch)=($1,$2);
      $entrybranch =~ s/^T//;
      $entrybranch ||= 'HEAD';
    }
    close(CVSENTRIES);
  }
  return ($entryrev, $entrybranch);
}

sub cvstagexpand {
  my $entrybranch;
  if (open(CVSTAG, " $Path->{'real'}/CVS/Tag")) {
    while (<CVSTAG>) {
      next unless m|^T(.*)$|;
      $entrybranch = $1;
    }
    close(CVSTAG);
  }
  return $entrybranch || 'HEAD';
}

sub cvspath {
  my ($entriespath, $entryname) = split m|/(?!.*/)|, $Path->{'realf'};
  return '' unless open (CVSREPO, "<$entriespath/CVS/Repository");
  my $repopath = <CVSREPO>;
  $repopath =~ s/\s+//g;
  $repopath = '' if $repopath =~ m{^/};
  close(CVSREPO);
  return $repopath;
}

sub cvsversionexpand {
  if ($who eq 'source') {
    my ($entryrev,undef) = cvsentriesexpand();
    return $entryrev;
  }
  if ($who eq 'sourcedir') {
    return cvstagexpand();
  }
  return '';
}

sub cvsbranchexpand {
  if ($who eq 'source') {
    my (undef,$entrybranch) = cvsentriesexpand();
    return $entrybranch;
  }
  if ($who eq 'sourcedir') {
    return cvstagexpand();
  }
  return '';
}

sub gethgroot {
  my $hgpath = checkhg($Path->{'virt'}, $Path->{'real'});
  return $1 if $hgpath =~ /^\d+\s(.*)\.hg/;
  return '';
}

sub hgpathexpand {
  my $path = substr($Path->{'real'}, length gethgroot());
  $path =~ s{/+$}{};
  return $path;
}

sub hgdehex {
  my $data = shift;
  return '' if $data =~ /^\0*$/;
  return '' unless $data;
  $data =~ s/(.)/sprintf("%02x",(ord($1)))/gems;
  return $data;
}

sub hgversionexpand {
  my $hgroot = gethgroot();
  return 'tip' unless -d $hgroot;
  if (defined $HTTP->{'param'}->{'rev'} &&
      $HTTP->{'param'}->{'rev'} =~ /([a-f0-9]+)/i) {
    return $1;
  }
  my $sig;
  if (open(HGSTATE, '<', $hgroot . '/.hg/dirstate')) {
    my ($parent1, $parent2);
    read (HGSTATE, $parent1, 20);
    read (HGSTATE, $parent2, 20);
    close HGSTATE;
    $sig = hgdehex($parent1).hgdehex($parent2);
  }
  return $sig =~ /(.{12})/ ? $1 : 'tip';
}

sub hgbranchexpand {
  my $hgroot = gethgroot();
  return 'tip' unless -d $hgroot;
  # branch cache is a cache it might not be there
  # if it isn't, we simply offer tip
  # something better may be implemented eventually.
  my $branch;
  if (open(HGSTATE, '<', $hgroot . '/.hg/dirstate')) {
    my ($parent1, $parent2);
    read (HGSTATE, $parent1, 20);
    read (HGSTATE, $parent2, 20);
    close HGSTATE;
    $branch = $sig = hgdehex($parent1).hgdehex($parent2);
  }
  if (open(HGCACHE, '<', $hgroot . '/.hg/branch.cache')) {
    my (%branches, %versions, $line, $ver, $sig);
    while ($line = <HGCACHE>) {
      if ($line =~ /^([0-9a-f]{40}) (\S+)/) {
        ($ver, $branch) = ($1, $2);
        $versions{$branch} = $ver;
        $branches{$ver} = $branch unless $branch =~ /^\d+$/;
      }
    }
    $branch = $branches{$sig};
    close HGCACHE;
  }
  return $branch || 'tip';
}

sub pathname {
  my $prefix = '';
  $prefix = '/' . $Conf->prefix if defined $Conf->prefix;
  return url_quote ($prefix . $Path->{'virtf'});
}

sub urlpath {
  return url_quote ($Path->{'virtf'});
}

sub pathname_unquoted {
  return $Path->{'virtf'};
}

sub filename {
  return url_quote ($Path->{'file'});
}

sub virtfold {
  return url_quote ($Path->{'svnvirt'});
}

sub virttree {
  return url_quote ($Path->{'svntree'});
}

sub treename {
  return $Conf->{'treename'};
}

sub bonsaicvsroot {
  return $Conf->{'bonsaicvsroot'};
}

sub cleanquery {
  my $s = shift;
  $s =~ tr/+/ /;
  $s =~ s/%(\w\w)/chr(hex $1)/ge;
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  $s =~ s/"/&quot;/g;
  return $s;
}

sub titleexpand {
  if ($who eq 'source' || $who eq 'sourcedir' || $who eq 'diff') {
    my $virtf = cleanquery $Path->{'virtf'};
    return &treename.' '.$Conf->sourcerootname.$virtf;
  }
  if ($who eq 'ident') {
    my $i = cleanquery $HTTP->{'param'}->{'i'};
    return &treename.' identifier search'.
           ($i ? " \"$i\"" : '');
  }
  if ($who eq 'search') {
    my $s = cleanquery $HTTP->{'param'}->{'string'};

    return &treename.' freetext search'.
           ($s ? " \"$s\"" : '');
  }
  if ($who eq 'find') {
    my $s = cleanquery $HTTP->{'param'}->{'string'};
    return &treename.' file search'.
           ($s ? " \"$s\"" : '');
  }
}


sub thisurl {
  my $url = $HTTP->{'this_url'};
  $url =~ s/\?$//;
  $url =~ s/([\&\;\=])/sprintf('%%%02x',(unpack('c',$1)))/ge;
  return $url;
}


sub baseurl {
  return $Conf->baseurl;
}

sub rooturl {
  my $root = $Conf->baseurl;
  $root = $1 if $root =~ m{^(.*[^/])/[^/]*$};
  return $root;
}

sub stylesheet {
  my $alt = shift;
  my $pre = "alt$alt-" if defined $alt;
  my $kind;
  $kind = 'style' if -f ('style/' . $pre . "style.css");
  my $ext;
  if ($Path->{'file'}) {
    $ext = $1 if $Path->{'file'} =~ /\.(\w+)$/;
  } else {
    $ext = 'dir' unless $Path->{'file'};
  }
  $kind = $ext if -f ("style/$pre$ext.css");
  return '' unless $kind;
  return "$pre$kind.css";
}

sub stylesheets {
  my $stylesheet;
  my $baseurl = baseurl();
  $stylesheet = stylesheet();
  my $type = 'stylesheet';
  my $style = 'Screen Look';
  my $index = 0 ;
  my $stylesheets;
  while ($stylesheet) {
    $stylesheets .= "<link rel='$type' title='$title' href='$baseurl/style/$stylesheet' type='text/css'>\n" if $stylesheet;
    $type = 'alternate stylesheet';
    return $stylesheets unless $stylesheet = stylesheet(++$index);
    $title = "Alt-$index";
  }
}

sub dotdoturl {
  my $url = $Conf->baseurl;
  $url =~ s@/$@@;
  $url =~ s@/[^/]*$@@;
  return $url;
}

# This one isn't too bad either.  We just expand the "modes" template
# by filling in all the relevant values in the nested "modelink"
# template.
sub modeexpand {
  my $templ = shift;
  my $modex = '';
  my @mlist = ();
  local $mode;

  if ($who eq 'source' || $who eq 'sourcedir') {
    push(@mlist, "<b><i>source navigation</i></b>");
  } else {
    push(@mlist, &fileref("source navigation", $Path->{'virtf'}));
  }

  if ($who eq 'diff') {
    push(@mlist, "<b><i>diff markup</i></b>");

  } elsif (($who eq 'source' || $who eq 'sourcedir') && $Path->{'file'}) {
    push(@mlist, &diffref("diff markup", $Path->{'virtf'}));
  }

  if ($who eq 'ident') {
    push(@mlist, "<b><i>identifier search</i></b>");
  } else {
    push(@mlist, &idref(undef,"identifier search", ""));
  }

  if ($who eq 'search') {
    push(@mlist, "<b><i>freetext search</i></b>");
  } else {
    push(@mlist, "<a href=\"$Conf->{virtroot}/search".
         &urlargs."\">freetext search</a>");
  }

  if ($who eq 'find') {
    push(@mlist, "<b><i>file search</i></b>");
  } else {
    push(@mlist, "<a href=\"$Conf->{virtroot}/find".
         &urlargs."\">file search</a>");
  }

  foreach $mode (@mlist) {
    $modex .= &expandtemplate($templ,
                              ('modelink', sub { return $mode; }));
  }

  return $modex;
}

# This is where it gets a bit tricky.  varexpand expands the
# "variables" template using varname and varlinks, the latter in turn
# expands the nested "varlinks" template using varval.
sub varlinks {
  my $templ = shift;
  my $vlex = '';
  my ($val, $oldval);
  local $vallink;

  $oldval = $allvariable_{$var};
  foreach $val ($Conf->varrange($var)) {
    if ($val eq $oldval) {
      $vallink = "<b><i>$val</i></b>";
    } else {
      if ($who eq 'source' || $who eq 'sourcedir') {
        $vallink = &fileref($val,
                            $Conf->mappath($Path->{'virtf'},
                                           "$var=$val"),
                            0,
                            "$var=$val");

      } elsif ($who eq 'diff') {
        $vallink = &diffref($val, $Path->{'virtf'}, "$var=$val");

      } elsif ($who eq 'ident') {
        $vallink = &idref($val, $identifier, undef, "$var=$val");

      } elsif ($who eq 'search') {
        $vallink = "<a href=\"$Conf->{virtroot}/search".
          &urlargs("$var=$val",
                   "string=".$HTTP->{'param'}->{'string'}).
                     "\">$val</a>";

      } elsif ($who eq 'find') {
        $vallink = "<a href=\"$Conf->{virtroot}/find".
          &urlargs("$var=$val",
                   "string=".$HTTP->{'param'}->{'string'}).
                     "\">$val</a>";
      }
    }
    $vlex .= &expandtemplate($templ,
                             ('varvalue', sub { return $vallink; }));

  }
  return $vlex;
}


sub varexpand {
    my $templ = shift;
    my $varex = '';
    local $var;

    foreach $var (@allvariables_) {
        $varex .= &expandtemplate($templ,
                                  ('varname', sub {
                                     return $Conf->vardescription($var);
                                   }
                                  ),
                                  ('varlinks', \&varlinks));
    }
    return $varex;
}

sub makeheader {
  local $who = shift;
  $template = undef;
  my $def_templ = "<html><title>(".&treename.")</title><body>\n<hr>\n";

  if ($who eq "sourcedir" && $Conf->sourcedirhead) {
    if (!open(TEMPL, $Conf->sourcedirhead)) {
      &warning("Template ".$Conf->sourcedirhead." does not exist.", 'sourcedirhead');
      $template = $def_templ;
    }
  } elsif (($who eq "source" || $who eq 'sourcedir') && $Conf->sourcehead) {
    if (!open(TEMPL, $Conf->sourcehead)) {
      &warning("Template ".$Conf->sourcehead." does not exist.", 'sourcehead');
      $template = $def_templ;
    }
  } elsif ($who eq "find" && $Conf->findhead) {
    if (!open(TEMPL, $Conf->findhead)) {
      &warning("Template ".$Conf->findhead." does not exist.", 'findhead');
      $template = $def_templ;
    }
  } elsif ($who eq "ident" && $Conf->identhead) {
    if (!open(TEMPL, $Conf->identhead)) {
      &warning("Template ".$Conf->identhead." does not exist.", 'identhead');
      $template = $def_templ;
    }
  } elsif ($who eq "search" && $Conf->searchhead) {
    if (!open(TEMPL, $Conf->searchhead)) {
      &warning("Template ".$Conf->searchhead." does not exist.", 'searchhead');
      $template = $def_templ;
    }
  } elsif ($who eq "diff" && $Conf->diffhead) {
    if (!open(TEMPL, $Conf->diffhead)) {
      &warning("Template ".$Conf->diffhead." does not exist.", 'diffhead');
      $template = $def_templ;
    }
  } elsif ($Conf->htmlhead) {
    if (!open(TEMPL, $Conf->htmlhead)) {
      &warning("Template ".$Conf->htmlhead." does not exist.", 'htmlhead');
      $template = $def_templ;
    }
  }

  if (!$template) {
    $save = $/; undef($/);
    $template = <TEMPL>;
    $/ = $save;
    close(TEMPL);
  }

  print(
#"<!doctype html public \"-//W3C//DTD HTML 3.2//EN\">\n",
#          "<html>\n",
#          "<head>\n",
#          "<title>",$Conf->sourcerootname," Cross Reference</title>\n",
#          "<base href=\"",$Conf->baseurl,"\">\n",
#          "</head>\n",

        &bigexpandtemplate($template)
  );
}

sub revoverride {
  return '' unless defined $HTTP->{'param'}->{'rev'};
  return '' unless $HTTP->{'param'}->{'rev'} =~ /([a-f0-9]+)/i;
  return "<h2>Asking version control to show revision $1</h2>";
}

sub bigexpandtemplate {
  my $template = shift;
  $template = &Local::localexpandtemplate($template);
  return expandtemplate($template,
    ('title',         \&titleexpand),
    ('banner',        \&bannerexpand),
    ('baseurl',       \&baseurl),
    ('stylesheet',    \&stylesheet),
    ('stylesheets',   \&stylesheets),
    ('dotdoturl',     \&dotdoturl),
    ('thisurl',       \&thisurl),
    ('pathname',      \&filepathname),
    ('filename',      \&filename),
    ('revoverride',   \&revoverride),
    ('virtfold',      \&virtfold),
    ('virttree',      \&virttree),
    ('urlpath',       \&urlpath),
    ('treename',      \&treename),
    ('modes',         \&modeexpand),
    ('bonsaicvsroot', \&bonsaicvsroot),
    ('cvspath',       \&cvspath),
    ('cvsversion',    \&cvsversionexpand),
    ('cvsbranch',     \&cvsbranchexpand),
    ('hgpath',        \&hgpathexpand),
    ('hgversion',     \&hgversionexpand),
    ('hgbranch',      \&hgbranchexpand),
    ('variables',     \&varexpand));
}

sub blamerefs {
  my ($pathname, $lines) = (@_);

  $who = 'source';
  fixpaths($pathname);
  my $template = "";
  if ($Conf->identref) {
    unless (open(TEMPL, $Conf->identref)) {
      &warning("Template ".$Conf->identref." does not exist.", 'identref');
    } else {
      local $/;
      $template = <TEMPL>;
      close(TEMPL);
    }
  }

  return bigexpandtemplate(&expandtemplate($template,
                           ('fpos', sub { return $lines; })
                           ));
}

sub makefooter {
  local $who = shift;
  $template = undef;
  my $def_templ = "<hr>\n</body>\n";

  if ($who eq "sourcedir" && $Conf->sourcedirtail) {
    if (!open(TEMPL, $Conf->sourcedirtail)) {
      &warning("Template ".$Conf->sourcedirtail." does not exist.", 'sourcedirtail');
      $template = $def_templ;
    }
  } elsif (($who eq "source" || $who eq 'sourcedir') && $Conf->sourcetail) {
    if (!open(TEMPL, $Conf->sourcetail)) {
      &warning("Template ".$Conf->sourcetail." does not exist.", 'sourcetail');
      $template = $def_templ;
    }
  } elsif ($who eq "find" && $Conf->findtail) {
    if (!open(TEMPL, $Conf->findtail)) {
      &warning("Template ".$Conf->findtail." does not exist.", 'findtail');
      $template = $def_templ;
    }
  } elsif ($who eq "ident" && $Conf->identtail) {
    if (!open(TEMPL, $Conf->identtail)) {
      &warning("Template ".$Conf->identtail." does not exist.", 'identtail');
      $template = $def_templ;
    }
  } elsif ($who eq "search" && $Conf->searchtail) {
    if (!open(TEMPL, $Conf->searchtail)) {
      &warning("Template ".$Conf->searchtail." does not exist.", 'searchtail');
      $template = $def_templ;
    }
  } elsif ($who eq "diff" && $Conf->difftail) {
    if (!open(TEMPL, $Conf->difftail)) {
      &warning("Template ".$Conf->difftail." does not exist.", 'difftail');
      $template = $def_templ;
    }
  } elsif ($Conf->htmltail) {
    if (!open(TEMPL, $Conf->htmltail)) {
      &warning("Template ".$Conf->htmltail." does not exist.", 'htmltail');
      $template = $def_templ;
    }
  }

  if (!$template) {
    $save = $/; undef($/);
    $template = <TEMPL>;
    $/ = $save;
    close(TEMPL);
  }

  print(&expandtemplate($template,
                        ('banner',    \&bannerexpand),
                        ('thisurl',   \&thisurl),
                        ('modes',     \&modeexpand),
                        ('variables', \&varexpand),
                        ('baseurl',   \&baseurl),
                        ('dotdoturl', \&dotdoturl),
                       ),
        "</html>\n");
}

sub url_quote {
  my($toencode) = (@_);
# don't escape /
  $toencode=~s|([^a-zA-Z0-9_/\-.])|uc sprintf("%%%02x",ord($1))|eg;
  return $toencode;
}

my %hgcache = ();

sub checkhg {
  my ($virt, $oreal) = @_;
  my $real = $oreal;
  $real =~ s{/$}{};
  $virt =~ s{^/}{};
  my @dirs;# = split m%/%, $virt;
  while (!defined $hgcache{$real} && $real) {
    if (-d $real . '/.hg') {
      $hgcache{$real} = '0 '. $real . '/.hg/store/data';
      # $Path->{'hgroot'} = $real;
      last;
    }
    $real =~ s{/([^/]*)$}{};
    unshift @dirs, $1;
  }
  if (defined $hgcache{$real}) {
    my $hgpath = $hgcache{$real};
    my $ll = 0 + $hgpath;
    $hgpath =~ s/^\d+ //;
    $ll = 0 + $hgcache{$real};
    while (scalar @dirs) {
      my $dir = '/' . (shift @dirs);
      $real .= $dir;
      if ($dir =~ s/([A-Z])/_$1/g) {
        $dir = lc $dir;
      }
      $hgpath .= $dir;
      ++$ll;
      # this shows up in profiling (-d)
      # if we don't care about knowing if intermediate
      # directories exist, there's probably some way to skip some of these
      $hgcache{$real} = -d $hgpath ? "$ll ". $hgpath : "0";
    }
  }
  $real = $oreal;
  $real =~ s{/$}{};
  return $hgcache{$real};
}

1;
