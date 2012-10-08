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
my $version = '0.08_01';

my $build = Module::Build->new(
	module_name => 'PDL::Drawing::Prima',
	dist_version_from => 'lib/PDL/Drawing/Prima.pm.PL',
	dist_version => $version,
	license  => 'perl',
	configure_requires => {
		PDL						=> '2.4.10',
		Prima					=> '1.33',
		# meta_merge was added in v 0.28:
		'Module::Build'		=> 0.28,
	},
	build_requires => {
		# working here - I need to check the smoke reports to hone in on a
		# minimum required version:
		'ExtUtils::ParseXS'	=> '3.0',
	},
	requires => {
		# Due to the use of PerlIO, I need at least 5.8:
		perl					=> '5.8.0',
		PDL						=> '2.4.10',
		Prima					=> '1.35',
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

# Find the Prima library for linking on Windows architectures. This requires
# an unfortunately substantial amount of munging. :-(
if ($^O eq 'cygwin' or $^O =~ /MS/) {
	my $path = $Prima::Config::Config{libs};
	
	# Do we have a full path with no linker flags?
	if ($path =~ /.(lib)?Prima\.[^.]+$/) {
		$path = "-l:$path";
	}
	# Do we have linker flags?
	elsif ($path =~ /^-L\S+\s+-lPrima/) {
		# Construct a direct path to the library for the linker to use:
		$path =~ s/^-L/-l:/;
		$path =~ s/ -l/\//;
		$path .= '.dll';
	}
	# Anything else?
	else {
		croak("Unknown path [$path]; I expected either the exact path or a set of linker flags");
	}
	
	$build->extra_linker_flags($path);
}

$build->create_build_script;
