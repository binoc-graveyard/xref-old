package LXR::Shell;
use Fcntl;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(&check_defaults &get_lock);

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

sub get_lock {
  my ($db_dir, $task) = @_;
  my $pid_lock = "$db_dir/update-$task.pid";
  sysopen(PID, $pid_lock, O_RDWR | O_CREAT) ||
    die "could not open lock file $pid_lock";
  my $pid = <PID>;
  if (defined $pid) {
    chomp $pid;
    die "update $task process is probably already running as pid $pid\n" if (kill 0, $pid);
  }
  seek(PID, 0, 0) ||
    die "could not rewind lock file $pid_lock";
  print PID $$;
  close PID;
  return $pid_lock;
}
