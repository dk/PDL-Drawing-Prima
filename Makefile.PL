# This was written based on some guidelines from:
# http://sourceforge.net/apps/mediawiki/pdl/index.php?title=How_to_call_C_functions_from_PDL

use strict;
use warnings;
use PDL::Core::Dev;
use ExtUtils::MakeMaker;
use Prima::Config;
use Config;

my $pack = [qw(pdlprima.pd Prima PDL::Drawing::Prima)];
my %hash = pdlpp_stdargs($pack);

$hash{VERSION_FROM}="pdlprima.pd";
$hash{INC} .= $Prima::Config::Config{inc};
my %DEFINES=map { my @z = split('=', $_, 2); scalar(@z)?(@z):($_ => 1)} @{$Prima::Config::Config{cdefs}};
$hash{CCFLAGS} .= join( ' ' , map { $Prima::Config::Config{cdefflag}.$_.'='.$DEFINES{$_}} keys %DEFINES);

# Not sure if this is necessary, but it was in PDL::PrimaImage, so I'm including
# it here in case it helps with, perhaps, OS/2.
$hash{OBJECT}="Prima\$(OBJ_EXT)";

# Find the Prima library for linking:
if ($^O =~ /MS/ or $^O eq 'cygwin') {
	my $path = $Prima::Config::Config{dlname};
	# Extract the path. This assumes that the path seperator is a single
	# character, but otherwise is not system-specific. Since it only applies
	# to MS and Cygwin, I think it'll be fine:
	die "Unable to determine the Prima library name\n"
		unless $path =~ s/.Prima\.[^.]+$//;
	push @{$hash{LIBS}}, "-L$path -lPrima";
}

## Required for Perl 5.14.1 ##
$hash{CCFLAGS} .= $Config{ccflags};

# Make it install my module files:
$hash{PM} = {
	  'Prima.pm'	=> 'blib/lib/PDL/Drawing/Prima.pm'
};

# Due to the use of PerlIO, I need at least 5.8:
$hash{MIN_PERL_VERSION} = '5.8.0';

WriteMakefile(%hash);

sub MY::postamble {
	pdlpp_postamble($pack);
}
