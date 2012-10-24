package ExtUtils::Builder::AutoDetect;

use Moo;

use Carp 'croak';
use ExtUtils::Config;
use ExtUtils::Helpers 'split_like_shell';
use Module::Load;
use Perl::OSType 'is_os_type';

has config => (
	is      => 'ro',
	default => sub { ExtUtils::Config->new },
);

sub _get_opt {
	my ($self, $opts, $name) = @_;
	return delete $opts->{$name} if defined $opts and defined $opts->{$name};
	return $self->config->get($name);
}

sub _split_opt {
	my ($self, $opts, $name) = @_;
	my $ret = _get_opt($self, $opts, $name);
	return ref($ret) ? $ret : [ split_like_shell($ret) ];
}

sub _make_command {
	my ($self, $shortname, $command, %options) = @_;
	my $module = "ExtUtils::Builder::$shortname";
	load($module);
	my @command = ref $command ? @{$command} : split_like_shell($command);
	my %env = $command[0] =~ / \w+ = \S+ /x ? split /=/, shift @command, 2 : ();
	my $thingie = $module->new(command => shift @command, env => \%env, %options);
	$thingie->add_argument(ranking => 0, value => \@command) if @command;
	return $thingie;
}

sub _is_gcc {
	my ($self, $cc, $opts) = @_;
	return $self->_get_opt($opts, 'gccversion') || $cc =~ / ^ gcc /ix;
}

sub _filter_args {
	my ($opts, @names) = @_;
	return map { $_ => delete $opts->{$_} } grep { exists $opts->{$_} } @names;
}

sub _get_compiler {
	my ($self, $opts) = @_;
	my $os = delete $opts->{osname} || $^O;
	my $cc = $self->_get_opt($opts, 'cc');
	my $module = $self->_is_gcc($cc, $opts) ? 'GCC' : is_os_type('Unix', $os) ? 'Unixy' : is_os_type('Windows', $os) ? 'MSVC' : croak 'Your platform is not supported yet';
	my %args = (_filter_args($opts, qw/language type/), cccdlflags => $self->_split_opt($opts, 'cccdlflags'));
	return $self->_make_command("Compiler::$module", $cc, %args);
}

sub get_compiler {
	my ($self, %opts) = @_;
	my $compiler = $self->_get_compiler(\%opts);
	if (my $profile = delete $opts{profile}) {
		my $profile_module = "ExtUtils::Builder::Profile::$profile";
		load($profile_module);
		$profile_module->process_compiler($compiler, $self->config, \%opts);
	}
	if (my $include_dirs = delete $opts{include_dirs}) {
		$compiler->add_include_dirs($include_dirs);
	}
	if (my $defines = delete $opts{define}) {
		$compiler->add_defines($defines);
	}
	if (my $extra = delete $opts{extra_args}) {
		$compiler->add_argument(value => $extra);
	}
	croak 'Unkown options: ' . join ',', keys %opts if keys %opts;
	return $compiler;
}

sub _lddlflags {
	my ($self, $opts) = @_;
	return delete $opts->{lddlflags} if defined $opts->{lddlflags};
	my $lddlflags = $self->config->get('lddlflags');
	my $optimize = $self->_get_opt($opts, 'optimize');
	$lddlflags =~ s/ ?\Q$optimize// if not delete $self->{auto_optimize};
	my %ldflags = map { ( $_ => 1 ) } @{ $self->_split_opt($opts, 'ldflags') };
	return [ grep { not $ldflags{$_} } split_like_shell($lddlflags) ];
}

sub _get_linker {
	my ($self, $opts) = @_;
	my $os = delete $opts->{osname} || $^O;
	my %args = _filter_args($opts, qw/type export langage/);
	my $ld = $self->_get_opt($opts, 'ld');
	my $module =
		$args{type} eq 'static-library' ? 'Ar' :
		$os eq 'darwin' ? 'GCC::Mach' :
		$self->_is_gcc($ld, $opts) ? 'GCC::ELF' :
		is_os_type('Unix', $os) ? 'Unixy' :
		croak 'Linking is not supported yet on your platform';
	%args = (%args, ccdlflags => $self->_split_opt($opts, 'ccdlflags'), lddlflags => $self->_lddlflags($opts)) if $module eq 'Unixy';
	return $self->_make_command("Linker::$module", $ld, %args);
}

sub get_linker {
	my ($self, %opts) = @_;
	my $linker = $self->_get_linker(\%opts);
	if (my $profile = delete $opts{profile}) {
		my $profile_module = "ExtUtils::Builder::Profile::$profile";
		load($profile_module);
		$profile_module->process_linker($linker, $self->config, %opts);
	}
	if (defined(my $shared = $opts{shared})) {
	}
	if (my $library_dirs = delete $opts{library_dirs}) {
		$linker->add_library_dirs($library_dirs);
	}
	if (my $libraries = delete $opts{libraries}) {
		$linker->add_libraries($libraries);
	}
	if (my $extra_args = delete $opts{extra_args}) {
		$linker->add_argument(ranking => 85, value => [ @{$extra_args} ]);
	}
	croak 'Unkown options: ' . join ',', keys %opts if keys %opts;
	return $linker;
}

1;
