package LXR::Shell;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(&check_defaults);

sub check_defaults {
  my ($defaultshash) = @_;
  my %defaults = %{$defaultshash};
  foreach my $app (keys %defaults) {
    my $value = $defaults{$app};
    if ($value ne '') {
      system("which $value >/dev/null 2>&1");
      if ($? == 0) {
        $value .= ' ';
      } else {
        warn("could not find $value for $app\n");
        $value = '';
      }
      $$defaultshash{$app} = $value;
    }
  }
}

