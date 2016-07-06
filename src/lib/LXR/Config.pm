# $Id: Config.pm,v 1.8 2006/12/30 02:53:48 reed%reedloden.com Exp $

package LXR::Config;

use LXR::Common;

require Exporter;
@ISA = qw(Exporter);
# @EXPORT = '';

$confname = 'lxr.conf';


sub new {
    my ($class, @parms) = @_;
    my $self = {};
    bless($self);
    $self->_initialize(@parms);
    return(treeify($self));
}

my %aliases;
sub resolvealias {
    my ($orig, $xp) = @_;
    my $real = $orig;
    my %seen = ();
    while (defined $aliases{$real}) {
        if (defined $xp) {
            return ${$xp}{$real} if (defined ${$xp}{$real});
        }
        # detect alias loops
        if ($seen{$aliases{$real}}) {
            warn "alias loops: $real <=> " . $aliases{$real};
            return $real;
        }
        $real = $aliases{$real};
        $seen{$real} = 1;
    }
    return $real;
}

sub treeify {
    my ($self) = @_;

    #If there are multiple definitions of sourceroot in lxr.conf then
    #this installation is configured for multiple trees. For a single
    #tree "sourceroot" is a single directory where the source can be
    #found. If the file contains multiple definitions of sourceroot then
    #each definition is a tree,directory pair.

    #remove the extra space that i stupidly added when parsing lxr.conf
    $self->{'sourceroot'} =~ s/^\s+//;
    $self->{'sourceprefix'} =~ s/^\s+//;
    $self->{'rewriteurl'} =~ s/^\s+//;
    my $baseurl = $self->{'baseurl'};
    if ($baseurl =~ m!^https?://([^/]+)(/.*)!) {
      my ($hostport, $path) = ($1, $2);
      my $https = env_or('HTTPS', 0);
      my $server_name = env_or('SERVER_NAME', 'localhost');
      my $default_port = $https ? 443 : 80;
      my $env_port = env_or('SERVER_PORT', '80');
      my $port = $default_port eq $env_port ? '' : ':' . $env_port;
      my $proto = $default_port == 443 ? 'https://' : 'http://';
      $baseurl = join('',
           $proto,
           $server_name,
           $port,
           $path);
    } else {
      my $https = env_or('HTTPS', 0);
      $baseurl = ($https ? 'https://' : 'http://') . $baseurl;
    }
    $self->{'baseurl'} = $baseurl;
    if ((($self->{'virtroot'} || '') eq '') &&
        $baseurl =~ m{https?://[^/]*?(/.+?)/?$}) {
        # auto detect virtroot
        $self->{'virtroot'} = $1;
    }

    if ($self->{'sourceroot'} =~ /\S\s+\S/) {
        $self->{'oldroot'} = $self->{'sourceroot'};

        #since there's whitespace within the root directory definition
        #there is one or more tree defined. (Using directory names with
        #embedded spaces here would be a bad thing.)
        my %treehash = split(/\s+/, $self->{'sourceroot'});
        $self->{'alias'} =~ s/^\s+//;
        %aliases = split(/\s+/, $self->{'alias'});
        foreach my $alias (keys %aliases) {
            if (defined $treehash{$alias}) {
if (0) {
                print STDERR ("Defining an alias for an existing tree '$alias'");
}
                next;
            }
            $treehash{$alias} = $treehash{resolvealias($alias)};
        }
        $self->{'treehash'} = \%treehash;

        my %rewritehash = split(/\s+/, $self->{'rewriteurl'});

        my @treelist = sort keys %treehash;
        $self->{'trees'} = \@treelist;

        {
            # To compute which tree we're looking at, grab the second to last
            # component from the script name which will be of the form:
            # /seamonkey/source
            my $treename = $ENV{'SCRIPT_NAME'};
            $treename =~ s|.*/([^/]+)/[^/]*|$1|;
            my $root = $treehash{$treename};
            if (defined $root) {
                $self->{'treename'} = $treename;
                # Match the tree name against our list of trees and extract
                # the proper directory. Set "sourceroot" to this directory.
                $self->{'sourceroot'} = $root;

                #set srcrootname to tree name
                $self->{'srcrootname'} = $treename;

                #set rewriteurl to tree name
                $self->{'rewriteurl'} = $rewritehash{$treename};

                #append tree name to virtroot
                $self->{'virtroot'} .= '/' . $treename;

                #store the original baseurl as realbaseurl for use by index.cgi
                $self->{'realbaseurl'} = $self->{'baseurl'};

                #append tree name to baseurl
                $self->{'baseurl'} .= $treename;

                #append tree name to dbdir
                $self->{'dbdir'} .= "/" . (resolvealias($treename));
            }
        }

        #find the cvsroot to sed in proper bonsai url
        my $path = $self->{'sourceroot'};
        if (defined $path) {
          my @pathdirs = split(/\//, $path);
          my $pathnum = @pathdirs;
          $self->{'bonsaicvsroot'} = $pathdirs[$pathnum - 1];
        }

        my %treehashp = split(/\s+/, $self->{'sourceprefix'});
        foreach my $alias (keys %aliases) {
            if (defined $treehash{$alias}) {
if (0) {
                print STDERR ("Defining an alias for an existing sourceprefix '$alias'");
}
                next;
            }
            $treehashp{$alias} = $treehash{resolvealias($alias, \%treehashp)};
        }
        my $treename = $self->{'treename'};
        my $sourceprefix;
        if (defined $treename) {
            $sourceprefix = $treehashp{resolvealias($treename, \%treehashp)};
        }
        $self->{'sourceprefix'} = $sourceprefix;
    } else {
        $self->{'treename'} = '';
    }

    return($self);
}

sub makevalueset {
    my $val = shift;
    my @valset;

    if ($val =~ /^\s*\(([^\)]*)\)/) {
	@valset = split(/\s*,\s*/,$1);
    } elsif ($val =~ /^\s*\[\s*(\S*)\s*\]/) {
	if (open(VALUESET, "$1")) {
	    $val = join('',<VALUESET>);
	    close(VALUESET);
	    @valset = split("\n",$val);
	} else {
	    @valset = ();
	}
    } else {
	@valset = ();
    }
    return(@valset);
}


sub parseconf {
    my $line = shift;
    my @items = ();
    my $item;

    foreach $item ($line =~ /\s*(\[.*?\]|\(.*?\)|\".*?\"|\S+)\s*(?:$|,)/g) {
	if ($item =~ /^\[\s*(.*?)\s*\]/) {
	    if (open(LISTF, "$1")) {
		$item = '('.join(',',<LISTF>).')';
		close(LISTF);
	    } else {
		$item = '';
	    }
	}
	if ($item =~ s/^\((.*)\)/$1/s) {
	    $item = join("\0",($item =~ /\s*(\S+)\s*(?:$|,)/gs));
	}
	$item =~ s/^\"(.*)\"/$1/;

	push(@items, $item);
    }
    return(@items);
}


sub _initialize {
    my ($self, $conf) = @_;
    my ($dir, $arg);

    unless ($conf) {
        $conf = $0;
        if ($conf =~ m{/}) {
            $conf =~ s{/[^/]+$}{/};
        } else {
            $conf = './';
        }
	$conf .= $confname;
    }

    unless (open(CONFIG, $conf)) {
	&fatal("Couldn't open configuration file \"$conf\".");
    }

    $self->{'sourceroot'} = '';
    $self->{'sourceprefix'} = '';
    $self->{'rewriteurl'} = '';
    $self->{'alias'} = '';
    { my @ary = ();
    $self->{'variables'} = \@ary;
    }

    while (<CONFIG>) {
	s/\s*\#.*|\s+$//;
	next if /^$/;
	if (($dir, $arg) = /^\s*(\S+):\s*(.*)/) {
	    if ($dir eq 'variable') {
		@args = &parseconf($arg);
		if ($args[0]) {
		    $self->{vardescr}->{$args[0]} = $args[1];
		    push(@{$self->{variables}},$args[0]);
		    $self->{varrange}->{$args[0]} = [split(/\0/,$args[2])];
		    $self->{vdefault}->{$args[0]} = $args[3];
		    $self->{vdefault}->{$args[0]} ||=
			$self->{varrange}->{$args[0]}->[0];
		    $self->{variable}->{$args[0]} =
			$self->{vdefault}->{$args[0]};
		}
	    } elsif ($dir eq 'sourceroot' ||
                     $dir eq 'sourceprefix' ||
                     $dir eq 'sourceoverlay' ||
                     $dir eq 'alias' ||
		     $dir eq 'srcrootname' ||
                     $dir eq 'virtroot' ||
		     $dir eq 'baseurl' ||
		     $dir eq 'rewriteurl' ||
		     $dir eq 'incprefix' ||
		     $dir eq 'dbdir' ||
		     $dir eq 'bonsaihome' ||
		     $dir eq 'glimpsebin' ||
		     $dir eq 'htmlhead' ||
		     $dir eq 'htmltail' ||
		     $dir eq 'sourcehead' ||
		     $dir eq 'sourcetail' ||
		     $dir eq 'sourcedirhead' ||
		     $dir eq 'sourcedirtail' ||
		     $dir eq 'diffhead' ||
		     $dir eq 'difftail' ||
		     $dir eq 'findhead' ||
		     $dir eq 'findtail' ||
		     $dir eq 'identhead' ||
		     $dir eq 'identref' ||
		     $dir eq 'identtail' ||
		     $dir eq 'searchhead' ||
		     $dir eq 'searchtail' ||
		     $dir eq 'htmldir' ||
		     $dir eq 'treechooser' ||
		     $dir eq 'treeentry' ||
		     $dir eq 'revchooser' ||
		     $dir eq 'reventry' ||
		     0) {
		if ($arg =~ /([^\n]+)/) {
	            if ($dir eq 'sourceroot' ||
                        $dir eq 'sourceprefix' ||
                        $dir eq 'rewriteurl' ||
                        $dir eq 'alias') {
                        $self->{$dir} .= " " . $1;
                    }else{
                        $self->{$dir} = $1;
                    }
		}
	    } elsif ($dir eq 'map') {
		if ($arg =~ /(\S+)\s+(\S+)/) {
		    push(@{$self->{maplist}}, [$1,$2]);
		}
	    } else {
		&warning("Unknown config directive (\"$dir\")");
	    }
	    next;
	}
	&warning("Noise in config file (\"$_\")");
    }
}


sub allvariables {
    my $self = shift;
    return(@{$self->{variables}});
}


sub variable {
    my ($self, $var, $val) = @_;
    $self->{variable}->{$var} = $val if defined($val);
    return($self->{variable}->{$var});
}


sub vardefault {
    my ($self, $var) = @_;
    return($self->{vdefault}->{$var});
}


sub vardescription {
    my ($self, $var, $val) = @_;
    $self->{vardescr}->{$var} = $val if defined($val);
    return($self->{vardescr}->{$var});
}


sub varrange {
    my ($self, $var) = @_;
    return(@{$self->{varrange}->{$var}});
}


sub varexpand {
    my ($self, $exp) = @_;
    $exp =~ s/\$\{?(\w+)\}?/$self->{variable}->{$1}/g;
    return($exp);
}

sub varexpandit {
    my ($self, $item) = @_;
    return undef unless defined $self->{$item};
    return($self->varexpand($self->{$item}));
}



sub baseurl {
    my $self = shift;
    return varexpandit($self, 'baseurl');
}

sub realbaseurl {
    my $self = shift;
    return varexpandit($self, 'realbaseurl') || varexpandit($self, 'baseurl');
}

sub sourceroot {
    my $self = shift;
    return varexpandit($self, 'sourceroot');
}

sub treehash {
    my $self = shift;
    return %self->treehash;
}

sub prefix {
    my $self = shift;
    my $prefix = $self->{'sourceprefix'};
    return $prefix;
}

sub rewriteurl {
    my $self = shift;
    my $prefix = $self->{'rewriteurl'};
    return $prefix;
}

sub sourcerootname {
    my $self = shift;
    return($self->varexpand(defined $self->{'sourceprefix'} ? $self->{'sourceprefix'} : $self->{'srcrootname'}));
}

sub virtroot {
    my $self = shift;
    return varexpandit($self, 'virtroot');
}


sub incprefix {
    my $self = shift;
    return varexpandit($self, 'incprefix');
}


sub bonsaihome {
    my $self = shift;
    return varexpandit($self, 'bonsaihome');
}


sub dbdir {
    my $self = shift;
    return varexpandit($self, 'dbdir');
}


sub glimpsebin {
    my $self = shift;
    return varexpandit($self, 'glimpsebin');
}


sub htmlhead {
    my $self = shift;
    return varexpandit($self, 'htmlhead');
}


sub htmltail {
    my $self = shift;
    return varexpandit($self, 'htmltail');
}

sub diffhead {
    my $self = shift;
    return varexpandit($self, 'diffhead');
}

sub difftail {
    my $self = shift;
    return varexpandit($self, 'difftail');
}

sub sourcehead {
    my $self = shift;
    return varexpandit($self, 'sourcehead');
}

sub sourcetail {
    my $self = shift;
    return varexpandit($self, 'sourcetail');
}

sub sourcedirhead {
    my $self = shift;
    return varexpandit($self, 'sourcedirhead');
}

sub sourcedirtail {
    my $self = shift;
    return varexpandit($self, 'sourcedirtail');
}

sub findhead {
    my $self = shift;
    return varexpandit($self, 'findhead');
}

sub findtail {
    my $self = shift;
    return varexpandit($self, 'findtail');
}

sub identhead {
    my $self = shift;
    return varexpandit($self, 'identhead');
}

sub identref {
    my $self = shift;
    return varexpandit($self, 'identref');
}

sub identtail {
    my $self = shift;
    return varexpandit($self, 'identtail');
}

sub searchhead {
    my $self = shift;
    return varexpandit($self, 'searchhead');
}

sub searchtail {
    my $self = shift;
    return varexpandit($self, 'searchtail');
}


sub htmldir {
    my $self = shift;
    return varexpandit($self, 'htmldir');
}

sub treechooser {
    my $self = shift;
    return varexpandit($self, 'treechooser');
}

sub treeentry {
    my $self = shift;
    return varexpandit($self, 'treeentry');
}

sub revchooser {
    my $self = shift;
    return varexpandit($self, 'revchooser');
}

sub reventry {
    my $self = shift;
    return varexpandit($self, 'reventry');
}

sub mappath {
    my ($self, $path, @args) = @_;
    my (%oldvars) = %{$self->{variable}};
    my ($m);

    foreach $m (@args) {
	$self->{variable}->{$1} = $2 if $m =~ /(.*?)=(.*)/;
    }

    foreach $m (@{$self->{maplist}}) {
	$path =~ s/$m->[0]/$self->varexpand($m->[1])/e;
    }

    $self->{variable} = {%oldvars};
    return($path);
}

#sub mappath {
#    my ($self, $path) = @_;
#    my ($m);
#
#    foreach $m (@{$self->{maplist}}) {
#	$path =~ s/$m->[0]/$self->varexpand($m->[1])/e;
#    }
#    return($path);
#}

1;
