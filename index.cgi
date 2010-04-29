#!/usr/bin/perl
use lib 'lib';
use LXR::Common;
use LXR::Config;

($Conf, undef, $Path, $head) = &init($0);
print "$head
";

# this can be calculated from lxr.conf's baseurl parameter
# unless of course there are two urls which could map here
# http://konigsberg.mozilla.org/mxr-test/
# http://mxr-test.konigsberg.bugzilla.org/

my $myserver = $ENV{'HTTP_HOST'} || $ENV{'SERVER_NAME'};
my $depth = ($myserver =~ /[lm]xr.*\./) ? 2 : 3;
if ($ENV{SCRIPT_NAME}=~m%(?:/[^/]+){$depth,}%) {
open INDEX, "<index.html";
} else {
open INDEX, "<root/index.html";
}

{
local $/ = undef;
my $template = <INDEX>;
print &expandtemplate($template,
                      ('rootname', sub { return $Conf->{'sourceprefix'}; }),
                      ('treename', sub { return $Conf->{'treename'}; }),
                     );
}
close INDEX;

