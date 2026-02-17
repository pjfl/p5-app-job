package App::Job::Daemon;

use App::Job; our $VERSION = App::Job->VERSION;

use Class::Usul::Cmd::Constants qw( COMMA EXCEPTION_CLASS FALSE NUL OK SPC
                                    TRUE );
use IO::Socket::UNIX            qw( SOCK_DGRAM );
use Class::Usul::Cmd::Types     qw( NonEmptySimpleStr Object PositiveInt Str );
use File::DataClass::Types      qw( Path );
use Class::Usul::Cmd::Util      qw( emit get_user is_member nap now_dt tempdir
                                    throw time2str );
use English                     qw( -no_match_vars );
use Scalar::Util                qw( blessed );
use Type::Utils                 qw( class_type );
use Unexpected::Functions       qw( Unspecified );
use Try::Tiny;
use Daemon::Control;
use Moo;
use Class::Usul::Cmd::Options;

extends q(Class::Usul::Cmd);

=pod

=encoding utf-8

=head1 Name

App::Job::Daemon - One-line description of the modules purpose

=head1 Synopsis

   use App::Job::Daemon;

=head1 Description

=head1 Configuration and Environment

Defines the following public attributes;

=over 3

=item C<max_wait>

=cut

has 'max_wait' => is => 'ro', isa => PositiveInt, default => 10;

=item C<prefix>

=cut

has 'prefix' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { (split m{ :: }mx, blessed(shift))[-1] };

=item C<read_socket>

=cut

has 'read_socket' =>
   is      => 'lazy',
   isa     => Object,
   default => sub {
      my $self   = shift;
      my $path   = $self->_socket_path;
      my $socket = IO::Socket::UNIX->new(
         Local => "${path}", Type => SOCK_DGRAM
      );

      throw 'Cannot bind to socket [_1]: [_2]', [$path, $OS_ERROR]
         unless defined $socket;

      return $socket;
   };

=item C<schema>

=cut

has 'schema' =>
   is      => 'lazy',
   isa     => class_type('DBIx::Class::Schema'),
   default => sub {
      my $self   = shift;
      my $class  = $self->config->schema_class;
      my $schema = $class->connect(@{$self->config->connect_info});

      $class->config($self->config) if $class->can('config');

      return $schema;
   };

=item C<socket_ctime>

=cut

has 'socket_ctime' =>
   is      => 'rwp',
   isa     => PositiveInt,
   lazy    => TRUE,
   default => sub {
      my $self = shift;
      my $path = $self->_socket_path;

      return $path->exists ? $path->stat->{ctime} : 0;
   };

# Private attributes
has '_daemon_control' =>
   is      => 'lazy',
   isa     => Object,
   default => sub {
      my $self = shift;
      my $conf = $self->config;
      my $prog = $conf->bin->catfile($self->_program_name);
      my $args = {
         name         => blessed $self || $self,
         path         => $prog->pathname,

         directory    => $conf->appldir,
         program      => $prog,
         program_args => ['rundaemon'],

         pid_file     => $self->_pid_file->pathname,
         stderr_file  => $self->_stdio_file('err'),
         stdout_file  => $self->_stdio_file('out'),

         fork         => 2,
      };

      return Daemon::Control->new($args);
   };

has '_daemon_pid' =>
   is      => 'lazy',
   isa     => PositiveInt,
   clearer => TRUE,
   default => sub {
      my $self = shift;
      my $path = $self->_pid_file;

      return (($path->exists && !$path->empty ? $path->getline : 0) // 0);
   };

has '_last_run_path' =>
   is      => 'lazy',
   isa     => Path,
   default => sub {
      my $self = shift;
      my $file = $self->_program_name . '.last_run';

      return $self->config->tempdir->catfile($file)->chomp->lock;
   };

has '_pid_file' =>
   is      => 'lazy',
   isa     => Path,
   default => sub {
      my $self = shift;

      return $self->config->rundir->catfile($self->_program_name.'.pid')->chomp;
   };

has '_program_name' =>
   is      => 'lazy',
   isa     => NonEmptySimpleStr,
   default => sub { shift->config->prefix . '-jobserver' };

has '_socket_path' =>
   is      => 'lazy',
   isa     => Path,
   default => sub {
      my $self = shift;

      return $self->config->tempdir->catfile($self->_program_name . '.sock');
   };

has '_write_socket' =>
   is       => 'lazy',
   isa      => Object,
   clearer  => TRUE,
   init_arg => 'write_socket',
   builder  => '_build_write_socket';

has '_version_path' =>
   is      => 'lazy',
   isa     => Path,
   default => sub {
      my $self = shift;
      my $file = $self->_program_name . '.version';

      return $self->config->tempdir->catfile($file)->chomp->lock;
   };

=back

=head1 Subroutines/Methods

Defines the following public methods;

=over 3

=item C<BUILD>

=cut

# Construction
sub BUILD {}

=item C<run>

=cut

around 'run' => sub {
   my ($orig, $self) = @_;

   my $daemon = $self->_daemon_control;

   throw Unspecified, ['name'    ] unless $daemon->name;
   throw Unspecified, ['program' ] unless $daemon->program;
   throw Unspecified, ['pid file'] unless $daemon->pid_file;

   $daemon->gid(get_user($daemon->uid)->gid) if $daemon->uid && !$daemon->gid;

   $self->quiet(TRUE);

   return $orig->($self);
};

=item C<clear> - Clears left over locks in the event of failure

Clears left over locks in the event of failure

=cut

sub clear : method {
   my $self = shift;

   throw 'Cannot clear whilst running' if $self->is_running;

   my $prefix = $self->prefix;
   my $pid = $self->next_argv || $self->_daemon_pid;

   try { $self->lock->reset(k => "${prefix}_semaphore", p => $pid)  } catch {};
   try { $self->lock->reset(k => "${prefix}_starting",  p => $pid)  } catch {};
   try { $self->lock->reset(k => "${prefix}_stopping",  p => $pid)  } catch {};
   try { $self->lock->reset(k => $prefix, p => $pid) } catch { warn $_ };

   $self->_pid_file->unlink if $self->_pid_file->exists;

   return OK;
}

=item C<daemon_pid>

=cut

sub daemon_pid {
   my $self  = shift;
   my $start = time;
   my $pid;

   until ($pid = $self->_daemon_pid) {
      last if time - $start > $self->max_wait;

      $self->_clear_daemon_pid;
      nap 0.5;
   }

   return $pid;
}

=item C<is_running>

=cut

sub is_running {
   my $self = shift;

   return $self->_daemon_control->pid_running ? TRUE : FALSE;
}

=item C<last_run>

=cut

sub last_run {
   my $self = shift;
   my $last_run = $self->_last_run_path;

   return 'Never' unless $last_run->exists;

   my $r = $last_run->getline;

   $last_run->close;
   return $r;
}

=item C<restart> - Restart the server

Restart the server

=cut

sub restart : method {
   my $self = shift;

   $self->params->{restart} = [ { expected_rv => 1 } ];

   $self->stop if $self->is_running;

   return $self->start;
}

=item C<rundaemon> - Run the job dequeuing process

Called by L<Daemon::Control> when the job server starts

=cut

sub rundaemon : method {
   return shift->_rundaemon;
}

=item C<running_version>

=cut

sub running_version {
   my $self = shift;
   my $version;

   try {
      $version = $self->_version_path->getline;
      $self->_version_path->close;
   }
   catch {};

   return $version;
}

=item C<show_locks> - Show the contents of the lock table

Show the contents of the lock table

=cut

sub show_locks : method {
   my $self = shift;

   for my $ref (@{$self->lock->list || []}) {
      my $stime = time2str '%Y-%m-%d %H:%M:%S', $ref->{stime};

      emit join COMMA, $ref->{key}, $ref->{pid}, $stime, $ref->{timeout};
   }

   return OK;
}

=item C<show_warnings> - Show server warnings

Show server warnings

=cut

sub show_warnings : method {
   my $self = shift;

   $self->_daemon_control->do_show_warnings;
   return OK;
}

=item C<start> - Start the server

Start the server

=cut

sub start : method {
   my $self = shift;

   $self->params->{start} = [ { expected_rv => 1 } ];
   $self->_wait_while_stopping;

   throw 'Already running' if $self->is_running;

   my $prefix = $self->prefix;

   throw 'Job daemon already starting' unless $self->lock->set(
      k => "${prefix}_starting", p => 666, async => TRUE
   );

   my $rv = $self->_daemon_control->do_start;

   if ($rv == OK and $self->_write_version) {
      $self->_raise_semaphore;
      $self->log->debug('Raised jobqueue semaphore on startup', $self);
   }

   return $rv;
}

=item C<status> - Show the current server status

Show the current server status

=cut

sub status : method {
   my $self = shift;

   $self->params->{status} = [ { expected_rv => 3 } ];

   return $self->_daemon_control->do_status;
}

=item C<stop> - Stop the server

Stop the server

=cut

sub stop : method {
   my $self = shift;

   $self->params->{stop} = [ { expected_rv => 1 } ];

   throw 'Not running' unless $self->is_running;

   my $prefix = $self->prefix;

   throw 'Job daemon already stopping' unless $self->lock->set(
      k => "${prefix}_stopping", p => 666, async =>TRUE
   );

   my $rv = $self->_daemon_control->do_stop;

   $self->_clear_daemon_pid;
   return $rv;
}

=item C<trigger> - Triggers the dequeueing process

Triggers the dequeueing process

=cut

sub trigger : method {
   my $self = shift;

   $self->_raise_semaphore;
   return OK;
}

=item C<write_socket>

=cut

sub write_socket {
   my $self = shift;

   $self->_clear_write_socket if $self->_is_write_socket_stale;

   return $self->_write_socket;
}

# Private methods
sub _build_write_socket {
   my $self        = shift;
   my $have_logged = FALSE;
   my $start       = time;
   my $socket;

   while (TRUE) {
      my $list     = $self->lock->list || [];
      my $starting = $self->_is_lock_set($list, 'starting');
      my $stopping = $self->_is_lock_set($list, 'stopping');
      my $started  = $self->_is_lock_set($list);
      my $exists   = $self->_socket_path->exists;

      if (!$stopping && !$starting && $started && $exists) {
         $socket = IO::Socket::UNIX->new(
            Peer => $self->_socket_path->pathname, Type => SOCK_DGRAM
         );

         last if $socket;

         unless ($have_logged) {
            $self->log->error(
               'Cannot connect to socket '. $self->_socket_path .
               " ${stopping} ${starting} ${started} ${exists} ${OS_ERROR}",
               $self
            );
            $have_logged = TRUE;
         }
      }

      if (time - $start > $self->max_wait) {
         my $message = 'Write socket timeout';

         $message = 'Socket file not found' unless $exists;
         $message = 'Job daemon not started' unless $started;
         $message = 'Job daemon still starting' if $starting;
         $message = 'Job daemon still stopping' if $stopping;

         throw "${message} [_1] [_2] [_3] [_4]",
               [$stopping, $starting, $started, $exists];
      }

      nap 0.5;
   }

   $self->_set_socket_ctime($self->_socket_path->stat->{ctime});

   return $socket;
}

sub _is_lock_set {
   my ($self, $list, $extn) = @_;

   my $prefix = $self->prefix;

   $prefix = "${prefix}_${extn}" if $extn;

   return is_member $prefix, map { $_->{key} } @{$list};
}

sub _is_write_socket_stale {
   my $self = shift;
   my $list = $self->lock->list || [];

   return TRUE if $self->_is_lock_set($list, 'starting');
   return TRUE if $self->_is_lock_set($list, 'stopping');

   my $path = $self->_socket_path;

   return TRUE unless $path->exists;

   return $path->stat->{ctime} > $self->socket_ctime ? TRUE : FALSE;
}

sub _lower_semaphore {
   my $self   = shift;
   my $buf    = NUL;
   my $prefix = $self->prefix;

   $self->read_socket->recv($buf, 1) until ($buf eq 'x');

   $self->lock->reset(k => "${prefix}_semaphore", p => 666);
   $self->log->debug('Lowered jobqueue semaphore', $self);
   return;
}

sub _raise_semaphore {
   my $self   = shift;
   my $prefix   = $self->prefix;
   my $socket = $self->write_socket or throw 'No write socket';

   return FALSE unless $self->lock->set(
      k => "${prefix}_semaphore", p => 666, async => TRUE
   );

   $socket->send('x');
   return TRUE;
}

# TODO: Add expected_rv
sub _runjob {
   my ($self, $job_id) = @_;

   my $expected_rv = 0;
   my $job;

   unless ($job = $self->schema->resultset('Job')->find($job_id)) {
      $self->log->error("Job ${job_id} unknown", $self);
      return OK;
   }

   my $label = $job->label;

   try {
      $self->log->info("Job ${label} running", $self);
      $job->run($job->run + 1);
      $job->update;

      my $opts = { err => 'out', timeout => $job->period - 60 };
      my $r    = $self->run_cmd([split SPC, $job->command], $opts);

      throw 'Return value greater than expected' if $r->rv > $expected_rv;

      $self->log->info("Job ${label} finished rv " . $r->rv, $self);
      $job->delete;
   }
   catch {
      $self->log->error("Job ${label} failed rv " . $_->rv , $self);

      if ($job->run + 1 > $job->max_runs) {
         $self->log->error("Job ${label} killed max. retries exceeded", $self);
         $job->delete;
      }
   };

   return OK;
}

sub _set_started_lock {
   my ($self, $lock, $prefix, $pid) = @_;

   unless ($lock->set(k => $prefix, p => $pid, t => 0, async => TRUE)) {
      try { $lock->reset(k => "${prefix}_starting", p => 666) } catch {};
      throw 'Job daemon already running';
   }

   my $path = $self->_socket_path;

   $path->unlink if $path->exists;
   $path->close;

   try { $lock->reset(k => "${prefix}_starting", p => 666) } catch {};

   return;
}

sub _should_run_job {
   my ($self, $job) = @_;

   return FALSE if $job->updated
      and $job->updated->clone->add(seconds => $job->period) > now_dt;

   if ($job->run + 1 > $job->max_runs) {
      $self->log->error(
         'Job ' . $job->label . ' killed max. retries exceeded', $self
      );
      $job->delete;
      return FALSE;
   }

   return TRUE;
}

sub _wait_while_stopping {
   my $self = shift;
   my $stopping;

   while (!defined($stopping) || $stopping) {
      $stopping = $self->_is_lock_set($self->lock->list, 'stopping');

      nap 0.5 if $stopping;
   }

   return;
}

sub _daemon_loop {
   my $self     = shift;
   my $stopping = FALSE;

   while (!$stopping) {
      $self->_lower_semaphore;

      for my $job ($self->schema->resultset('Job')->search({})->all) {
         if ($job->command eq 'stop_jobdaemon') {
            $job->delete;
            $stopping = TRUE;
            last;
         }

         next unless $self->_should_run_job($job);

         $job->updated(now_dt);
         $job->update;

         try {
            $self->run_cmd(
               [sub { $self->_runjob($job->id) }],
               { async => TRUE, detach => TRUE }
            );
         }
         catch { $self->log->error($_, $self) };

         my $line = time2str( '%Y-%m-%d %H:%M:%S' ) . SPC . $job->label;

         $self->_last_run_path->println($line);
         $self->_last_run_path->flush->close;
      }
   }

   return;
}

sub _rundaemon {
   my $self = shift;

   $ENV{uc $self->config->appclass . '_debug'} = $self->debug;
   $PROGRAM_NAME = $self->_program_name;

   $self->log->debug('Trying to start the job daemon', $self);

   my $lock   = $self->lock;
   my $prefix = $self->prefix;
   my $pid    = $PID;

   $self->_set_started_lock($lock, $prefix, $pid);
   $self->log->info("Started job daemon ${pid}", $self);

   my $reset = sub {
      $self->log->info("Stopping job daemon ${pid}", $self);
      $self->read_socket->close if $self->read_socket;
      $self->_socket_path->unlink if $self->_socket_path->exists;

      try { $lock->reset(k => "${prefix}_semaphore", p => 666) } catch {};
      try { $lock->reset(k => $prefix, p => $pid) } catch {};
      try { $lock->reset(k => "${prefix}_stopping",  p => 666) } catch {};

      return;
   };

   try { local $SIG{TERM} = sub { $reset->(); exit OK }; $self->_daemon_loop }
   catch { $self->log->error($_, $self) };

   $reset->();
   exit OK;
}

sub _stdio_file {
   my ($self, $extn, $name) = @_;

   $name //= $self->_program_name;

   return tempdir($self)->catfile("${name}.${extn}");
}

sub _write_version {
   my $self = shift;

   $self->_version_path->println($VERSION);
   $self->_version_path->close;
   return TRUE;
}

use namespace::autoclean;

1;

__END__

=back

=cut

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd>

=item L<Daemon::Control>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Job.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <lazarus@roxsoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
