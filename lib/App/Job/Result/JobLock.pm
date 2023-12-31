package App::Job::Result::JobLock;

use Class::Usul::Cmd::Util  qw( time2str );
use HTML::StateTable::Types qw( Int Str );
use Moo;

with 'HTML::StateTable::Result::Role';

has 'stime' => is => 'ro', isa => Str, init_arg => undef, default => sub {
   return time2str '%Y-%m-%d %H:%M:%S', shift->_stime;
};

has '_stime', => is => 'ro', isa => Int, init_arg => 'stime';

has 'key' => is => 'ro', isa => Str;

has 'pid' => is => 'ro', isa => Int;

has 'timeout' => is => 'ro', isa => Int;

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Job::Result::JobLock - One-line description of the modules purpose

=head1 Synopsis

   use App::Job::Result::JobLock;
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
