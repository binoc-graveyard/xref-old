#!/usr/bin/perl
use lib 'lib';
use LXR::Common;
use LXR::Config;

($Conf, undef, $Path, $head) = &init($0);
print "$head
";

unless (defined $Conf->{'trees'} &&
        $Conf->baseurl eq $Conf->realbaseurl) {
# this is the root of an individual tree
# or the root of the only tree
open INDEX, "<media/templates/template-source-index";
} else {
# this is a list of published trees
open INDEX, "<root-index.html";
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
