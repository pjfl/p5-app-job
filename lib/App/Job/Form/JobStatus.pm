package App::Job::Form::JobStatus;

use Class::Usul::Cmd::Util qw( time2str );
use HTML::Forms::Constants qw( FALSE META SPC TRUE );
use HTML::Forms::Types     qw( ArrayRef );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+title'               => default => 'Job System';
has '+default_wrapper_tag' => default => 'fieldset';
has '+do_form_wrapper'     => default => TRUE;
has '+fields_from_model'   => default => TRUE;
has '+info_message'        => default => 'Current status';

has 'jobdaemon' => is => 'ro', required => TRUE;

has 'model_fields' => is => 'lazy', isa => ArrayRef, default => sub {
   my $self = shift;

   return [
      'clear' => {
         html_name => 'submit', label => 'Clear Locks', type => 'Button',
         value     => 'clear', wrapper_class => ['inline input-button']
      },
      'start' => {
         html_name => 'submit', label => 'Start', type => 'Button',
         value     => 'start', wrapper_class => ['inline input-button']
      }
   ] unless $self->jobdaemon->is_running;

   return [
      'restart' => {
         html_name => 'submit', label => 'Restart', type => 'Button',
         value     => 'restart', wrapper_class => ['inline input-button']
      },
      'stop' => {
         html_name => 'submit', label => 'Stop', type => 'Button',
         value     => 'stop', wrapper_class => ['inline input-button']
      },
      'trigger' => {
         html_name => 'submit', label => 'Trigger', type => 'Button',
         value     => 'trigger', wrapper_class => ['inline input-button']
      },
   ];
};

has_field 'is_running' => type => 'Display';

has_field 'app_version' => type => 'Display';

has_field 'running_v' => type => 'Display', label => 'Running version';

has_field 'daemon_pid' => type => 'Display';

has_field 'start_time' => type => 'Display';

has_field 'last_run' => type => 'Display';

has_field 'last_job' => type => 'Display';

around 'after_build_fields' => sub {
   my ($orig, $self) = @_;

   $orig->($self);

   my $daemon   = $self->jobdaemon;
   my $running  = $daemon->is_running;
   my $last_job = (split SPC, $daemon->last_run)[-1];
   my $last_run = join SPC, (split SPC, $daemon->last_run)[0..1];

   $self->field('app_version')->default($daemon->VERSION);
   $self->field('daemon_pid')->default($running ? $daemon->daemon_pid : 'N/A');
   $self->field('is_running')->default($running ? 'Yes' : 'No');
   $self->field('last_job')->default($last_job);
   $self->field('last_run')->default($last_run);
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

=item L<HTML::Forms>

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
