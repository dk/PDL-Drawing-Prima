use Module::Build;
use strict;
use warnings;
use PDL::Core::Dev;
use Prima::Config;
use Config;

# These are lifted from PDL::Core::Dev, but use a less redundant style:
my $inc = PDL_INCLUDE;
$inc =~ s/-I//g;
my @incs = ($inc, @{$Prima::Config::Config{incpaths}});

# Explicitly set the version here; all .pm.PL files will use this:
my $version = '0.02_01';

my $build = Module::Build->new(
	module_name => 'PDL::Drawing::Prima',
	dist_version_from => 'lib/PDL/Drawing/Prima.pm.PL',
	dist_version => $version,
	license  => 'perl',
	configure_requires => {
		PDL						=> '2.4.9_014',
		Prima					=> '1.33',
		# working here - I need to check the smoke reports for the minimum
		# required version:
		'Module::Build'		=> '0',
	},
	build_requires => {
		# working here - I need to check the smoke reports for the minimum
		# required version:
		'ExtUtils::ParseXS'	=> '0',
	},
	requires => {
		# Due to the use of PerlIO, I need at least 5.8:
		perl					=> '5.8.0',
		PDL						=> '2.4.9_014',
		Prima					=> '1.33',
	},
	needs_compiler => 1,
	include_dirs => \@incs,
	meta_merge => {
		resources => {
			repository
				=> 'http://github.com/run4flat/PDL-Drawing-Prima',
#				=> {
#					web => 'http://github.com/run4flat/PDL-Drawing-Prima',
#					url => 'git://github.com/run4flat/PDL-Drawing-Prima.git',
#					type => 'git',
#				},
			bugtracker
				=> 'http://github.com/run4flat/PDL-Drawing-Prima/issues',
#				=> {
#					web => 'http://github.com/run4flat/PDL-Drawing-Prima/issues',
#				},
		},
		provides => {
			'PDL::Drawing::Prima' => {
				file => 'lib/PDL/Drawing/Prima.pm.PL',
				version => $version,
			},
			'PDL::Drawing::Prima::Utils' => {
				file => 'lib/PDL/Drawing/Prima/Utils.pm.PL',
				version => $version,
			},
		},
		no_index => {
			file => ['README.pod'],
			directory => [qw(examples t)],
		},
	},
);

# Find the Prima library for linking:
if ($^O =~ /MS/ or $^O eq 'cygwin') {
	my $path = $Prima::Config::Config{dlname};
	# Extract the path. This assumes that the path seperator is a single
	# character, but otherwise is not system-specific. Since it only applies
	# to MS and Cygwin, I think it'll be fine:
	die "Unable to determine the Prima library name\n"
		unless $path =~ s/.Prima\.[^.]+$//;
	$build->extra_linker_flags("-L$path", "-lPrima");
}

$build->create_build_script;
