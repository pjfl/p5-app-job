package App::Job::Form::JobStatus;

use Class::Usul::Time      qw( time2str );
use HTML::Forms::Constants qw( FALSE META TRUE );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+title'               => default => 'Job System';
has '+default_wrapper_tag' => default => 'fieldset';
has '+do_form_wrapper'     => default => TRUE;
has '+info_message'        => default => 'Current status';

has 'jobdaemon' => is => 'ro', required => TRUE;

has_field 'is_running' => type => 'Display';

has_field 'app_version' => type => 'Display';

has_field 'running_v' => type => 'Display';

has_field 'daemon_pid' => type => 'Display';

has_field 'start_time' => type => 'Display';

has_field 'last_run' => type => 'Display';

before 'after_build' => sub {
   my $self    = shift;
   my $daemon  = $self->jobdaemon;
   my $running = $daemon->is_running;

   $self->field('app_version')->default($daemon->VERSION);
   $self->field('daemon_pid')->default($running ? $daemon->daemon_pid : 'N/A');
   $self->field('is_running')->default($running ? 'Yes' : 'No');
   $self->field('last_run')->default($daemon->last_run);
   $self->field('running_v')->default(
      $running ? $daemon->running_version : 'N/A'
   );
   $self->field('start_time')->default(
      $running ? time2str '%Y-%m-%d %H:%M:%S', $daemon->socket_ctime : 'N/A'
   );
   return;
};

use namespace::autoclean -except => META;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Job::Form::JobStatus - One-line description of the modules purpose

=head1 Synopsis

   use App::Job::Form::JobStatus;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

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
