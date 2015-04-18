package Dist::Zilla::Plugin::MakeMaker::Runner;
# ABSTRACT: Test and build dists with a Makefile.PL

use Moose;
with(
  'Dist::Zilla::Role::BuildRunner',
  'Dist::Zilla::Role::TestRunner',
);

use namespace::autoclean;

use Config;

has 'make_path' => (
  isa     => 'Str',
  is      => 'ro',
  lazy    => 1,
  builder => '_build_make_path',
);

sub _build_make_path
{
  my $self = shift;

  my $build_perl = $self->zilla->build_perl;
  (
      $build_perl eq $^X
    ? $Config{make}
      # Extract $Config{make} from $build_perl
    : do { my $m = `$build_perl -V:make`; $m =~ /make='(.*)'/; $1 }
  ) || 'make'
}

sub build {
  my $self = shift;

  my $make = $self->make_path;

  my $makefile = $^O eq 'VMS' ? 'Descrip.MMS' : 'Makefile';

  return
    if -e $makefile and (stat 'Makefile.PL')[9] <= (stat $makefile)[9];

  $self->zilla->do_with_build_env(sub {
    my $build_perl = $self->zilla->build_perl;
    $self->log_debug("running $build_perl Makefile.PL");
    system($build_perl => qw(Makefile.PL INSTALLMAN1DIR=none INSTALLMAN3DIR=none)) and die "error with Makefile.PL\n";

    $self->log_debug("running $make");
    system($make) and die "error running $make\n";
  });

  return;
}

sub test {
  my ($self, $target, $arg) = @_;

  my $make = $self->make_path;
  $self->build;

  my $job_count = $arg && exists $arg->{jobs}
                ? $arg->{jobs}
                : $self->default_jobs;

  my $jobs = "j$job_count";
  my $ho = "HARNESS_OPTIONS";
  local $ENV{$ho} = $ENV{$ho} ? "$ENV{$ho}:$jobs" : $jobs;

  $self->log_debug(join(' ', "running $make test", ( $self->zilla->logger->get_debug ? 'TEST_VERBOSE=1' : () )));

  $self->zilla->do_with_build_env(sub {
    system($make, 'test',
      ( $self->zilla->logger->get_debug ? 'TEST_VERBOSE=1' : () ),
    ) and die "error running $make test\n";
  });

  return;
}

__PACKAGE__->meta->make_immutable;
1;
