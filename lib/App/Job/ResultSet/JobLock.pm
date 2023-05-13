package App::Job::ResultSet::JobLock;

use HTML::StateTable::Constants qw( COL_INFO_TYPE_ATTR FALSE TRUE );
use HTML::StateTable::Types     qw( ArrayRef Bool Int ResultRole Str Undef );
use Data::Page;
use Moo;
use MooX::HandlesVia;

has 'current_source_alias' => is => 'ro', isa => Str, default => 'me';

has 'daemon' => is => 'ro', required => TRUE;

has '_index' =>
   is       => 'rw',
   isa      => Int,
   lazy     => TRUE,
   default  => sub { shift->index_start };

has 'page'  =>
   is      => 'ro',
   isa     => Int,
   default => 1,
   trigger => \&reset,
   writer  => '_set_page';

has 'page_size' =>
   is      => 'ro',
   isa     => Int,
   default => 0,
   trigger => \&reset,
   writer  => '_set_page_size';

has 'paging' =>
   is      => 'ro',
   isa     => Bool,
   default => FALSE,
   writer  => '_set_paging';

has 'result_class' => is => 'ro', required => TRUE;

has '_results' =>
   is          => 'lazy',
   isa         => ArrayRef[ResultRole|Undef],
   builder     => 'build_results',
   handles_via => 'Array',
   handles     => { result_count => 'count' },
   clearer     => '_clear_results';

has 'table' => is => 'ro', required => TRUE, weak_ref => TRUE;

has 'total_results' =>
   is      => 'lazy',
   isa     => Int,
   writer  => '_set_total_results',
   default => sub { shift->result_count };

sub build_results {
   my $self    = shift;
   my $results = [];

   for my $lock (@{$self->daemon->lock->list || []}) {
      push @{$results}, $self->result_class->new($lock);
   }

   return $results;
}

sub column_info {
   my ($self, $name) = @_;

   my $attr = COL_INFO_TYPE_ATTR;

   if (my $column = $self->table->get_column($name)) {
      for my $trait (@{$column->cell_traits}) {
         return { $attr => 'TIMESTAMP' } if $trait =~ m{ date }imx;
         return { $attr => 'INTEGER' }   if $trait =~ m{ numeric }imx;
      }
   }

   return { $attr => 'TEXT' };
}

sub index_start {
   my $self = shift; return $self->page_size * ($self->page - 1);
}

sub next {
   my $self = shift;

   if ($self->paging) {
      return if $self->_index >= $self->index_start + $self->page_size;
   }

   return if $self->_index >= $self->total_results;

   my $result = $self->_results->[$self->_index];

   $self->_index($self->_index + 1);

   return $result;
}

sub pager {
   my $self = shift;

   return Data::Page->new(
      $self->total_results, $self->page_size, $self->page
   );
}

sub reset {
   my $self = shift;

   $self->_set_paging($self->page_size ? TRUE : FALSE);
   $self->_index($self->index_start);
   return;
}

sub result_source {
   return shift;
}

sub search {
   return shift;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Job::ResultSet::JobLock - One-line description of the modules purpose

=head1 Synopsis

   use App::Job::ResultSet::JobLock;
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
