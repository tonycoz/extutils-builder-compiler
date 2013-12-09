package ExtUtils::Builder::Role::Compiler;

use Moo::Role;

with qw/ExtUtils::Builder::Role::Command ExtUtils::Builder::Role::Binary/;

use ExtUtils::Builder::Action::Command;
use ExtUtils::Builder::Node;
use Module::Runtime ();

requires qw/add_include_dirs add_defines compile_flags _build_cc/;

has _cc => (
	is       => 'ro',
	builder  => '_build_cc',
	init_arg => 'cc',
	coerce   => sub {
		return ref $_[0] ? $_[0] : [ $_[0] ];
	},
);

sub cc {
	my $self = shift;
	return @{ $self->_cc };
}

around collect_arguments => sub {
	my ($orig, $self, @args) = @_;
	return ($self->$orig, $self->compile_flags(@args));
};

sub compile {
	my ($self, $from, $to, %opts) = @_;
	my @argv = $self->arguments($from, $to, %opts);
	my $main = ExtUtils::Builder::Action::Command->new(command => [ $self->cc, @argv ]);
	my $deps = [ $from, @{ $opts{dependencies} || [] } ];
	return ExtUtils::Builder::Node->new(target => $to, dependencies => $deps, actions => [$main]);
}

sub load_profile {
	my ($self, $module, $arguments) = @_;
	$module =~ s/ \A @ /ExtUtils::Builder::Profile::/xms;
	Module::Runtime::require_module($module);
	return $module->process_compiler($self, $arguments);
}

1;

