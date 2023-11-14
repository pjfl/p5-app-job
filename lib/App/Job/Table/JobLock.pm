package App::Job::Table::JobLock;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use App::Job::ResultSet::JobLock;
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::CheckAll';
with    'HTML::StateTable::Role::Form';

has '+caption' => default => 'Job Locks';

has '+paging' => default => FALSE;

has '+form_control_location' => default => 'BottomRight';

has 'jobdaemon' => is => 'ro', required => TRUE;

set_table_name 'joblocks';

setup_resultset sub {
   my $self  = shift;
   my $class = 'App::Job::ResultSet::JobLock';

   return $class->new(daemon => $self->jobdaemon, table => $self);
};

has_column 'key';

has_column 'pid' => cell_traits => ['Numeric'], label => 'PID';

has_column 'stime' => cell_traits => ['DateTime'], label => 'Set Time';

has_column 'timeout' => cell_traits => ['Numeric'];

has_column 'check' =>
   cell_traits => ['Checkbox'],
   label       => SPC,
   value       => 'key';

use namespace::autoclean -except => TABLE_META;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Job::Table::JobLock - One-line description of the modules purpose

=head1 Synopsis

   use App::Job::Table::JobLock;
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

=item L<HTML::StateTable>

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
