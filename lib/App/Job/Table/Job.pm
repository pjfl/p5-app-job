package App::Job::Table::Job;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::Configurable';
with    'HTML::StateTable::Role::Searchable';
with    'HTML::StateTable::Role::CheckAll';
with    'HTML::StateTable::Role::Form';
with    'HTML::StateTable::Role::Active';

has '+caption' => default => 'Jobs List';

has '+configurable_control_location' => default => 'TopRight';

has '+configurable_dialog_close' => default => sub {
   return shift->context->request->uri_for('img/cancel.svg')->as_string;
};

has '+configurable_label' => default => sub {
   return shift->context->request->uri_for('img/tune.svg')->as_string;
};

has '+form_control_location' => default => 'BottomRight';

has '+page_size_control_location' => default => 'BottomLeft';

set_table_name 'job';

has_column 'id' =>
   cell_traits => ['Numeric'],
   label       => 'ID',
   width       => '3rem';

has_column 'name' =>
   label      => 'Job Name',
   searchable => TRUE,
   sortable   => TRUE,
   title      => 'Sort by job';

has_column 'check' =>
   cell_traits => ['Checkbox'],
   label       => SPC,
   value       => 'id';

use namespace::autoclean -except => TABLE_META;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Job::Table::Job - One-line description of the modules purpose

=head1 Synopsis

   use App::Job::Table::Job;
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
