package ExtUtils::Builder::Role::Linker::Unixy;

use Moo::Role;

with 'ExtUtils::Builder::Role::Linker';

sub linker_flags {
	my ($self, $from, $to, %opts) = @_;
	my @ret;
	push @ret, map { $self->new_argument(ranking => $_->{ranking}, value => [ "-L$_->{value}" ]) } @{ $self->_library_dirs };
	push @ret, map { $self->new_argument(ranking => $_->{ranking}, value => [ "-l$_->{value}" ]) } @{ $self->_libraries };
	push @ret, $self->new_argument(ranking => 50, value => [ '-o' => $to, @{$from} ]);
	return @ret;
}

1;

