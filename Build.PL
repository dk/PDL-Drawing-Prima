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

# At one point I had this, to handle Prima's compiler define statements, but it
# looks like they're never used and I'm not sure how I can test their
# correctness. Also, these are for ExtUtils::MakeMaker, not Module::Build, so a
# suitable translation is required:
#my %DEFINES=map { my @z = split('=', $_, 2); scalar(@z)?(@z):($_ => 1)} @{$Prima::Config::Config{cdefs}};
#$hash{CCFLAGS} .= join( ' ' , map { $Prima::Config::Config{cdefflag}.$_.'='.$DEFINES{$_}} keys %DEFINES);
# Not sure if this is necessary, but it was in PDL::PrimaImage, so I'm including
# it here in case it helps with, perhaps, OS/2.
#$hash{OBJECT}="Prima\$(OBJ_EXT)";

my $build = Module::Build->new(
	module_name => 'PDL::Drawing::Prima',
	dist_version_from => 'lib/PDL/Drawing/Prima.pm.PL',
	license  => 'perl',
	requires => {
		# Due to the use of PerlIO, I need at least 5.8:
		perl					=> '5.8.0',
		PDL						=> '2.4.9_014',
		# working here - after the initial push, I need to relax these and
		# check the smoke reports for the minimum required version:
		'ExtUtils::ParseXS'	=> '3.05',
		Prima					=> '1.33',
	},
	needs_compiler => 1,
	PL_files => {
		'lib/PDL/Drawing/Prima.pm.PL'
			=> ['lib/PDL/Drawing/Prima.xs', 'lib/PDL/Drawing/Prima.pm'],
		'lib/PDL/Drawing/Prima/Utils.pm.PL'
			=> ['lib/PDL/Drawing/Prima/Utils.xs', 'lib/PDL/Drawing/Prima/Utils.pm'],
	},
	include_dirs => \@incs,
#	extra_linker_flags => $PDL::Config{MALLOCDBG}->{libs},
	
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
