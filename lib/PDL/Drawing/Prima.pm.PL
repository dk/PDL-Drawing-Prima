use strict;
use warnings;

# Invoke PDL::PP
my $base_name;
BEGIN {
	# .PL scripts are sent their filename, sans the .PL part. That's almost what
	# PDL::PP expects to see, so massage it into the proper form:
	$base_name = $ARGV[0];
	$base_name =~ s/\.pm//;
	
	# Handle backslashes for Windows paths:
	$base_name =~ s/\\/\\\\/g;
}
use PDL::PP (qw(PDL::Drawing::Prima PDL::Drawing::Prima), $base_name);

# Set the module version from the version stashed in the M::B object. The string
# passed to pp_setversion must include the quotes to ensure that it is processed
# as a string from the actual module:
use Module::Build;
my $build = Module::Build->current;
pp_setversion('"' . $build->dist_version . '"');

# Add the .xs file to the cleanup lists:
$build->add_to_cleanup("$base_name.xs");

use Carp qw(croak confess);

#our $PP_VERBOSE = 1;

pp_addpm({At=>'Top'},<<'ModuleMaterial');

use strict;
use warnings;
use PDL;
use PDL::Char;
use Scalar::Util 'blessed';
use Carp 'croak';
use PDL::Drawing::Prima::Utils;

# working here - use Exporter and set as 'EXPORT_OK' the functions
# pdl_of_patterns_for and pdl_of_handles_for. Their usage looks like this:
#  my $patterns = pdl_of_patterns_for($pat1, $pat2, ...);
#  my $handles  = pdl_of_handles_for($widget1, $widget2, ...);

=head1 NAME

PDL::Drawing::Prima - PDL-aware drawing functions for Prima widgets

=cut

ModuleMaterial

=head1 CPAN

You, gentle reader, are reading this documentation off of CPAN. I know this
because B<this> documentation does not show up in the final .pm files that are
installed on a user's computer. I have gone to great lengths to ensure that
the CPAN-visible documentation is up-to-date, but it may be incomplete in
certain circumstances since PDL autogenerates some of its documentation. If
you have any concerns regarding documentation skew, be sure to check the
documentation on your local machine.

=cut

# working here - what about lineJoin or lineEnd? These should be applicable to
# the line drawing routines?

pp_addpm({At=>'Top'},<<'ModuleMaterial');

=head1 SYNOPSIS

Each of the methods comes with a small sample snippet. To see how it
looks, copy this synopsis and replace the code in the
C<Example code goes here> block with the example code.

 use strict;
 use warnings;
 use PDL;
 use PDL::Drawing::Prima;
 use Prima qw(Application);
 
 my $window = Prima::MainWindow->create(
     text    => 'PDL::Drawing::Prima Test',
     onPaint => sub {
         my ( $self, $canvas) = @_;
 
         # wipe the canvas:
         $canvas->clear;
         
         ### Example code goes here ###
         
         # Draw a sine curve on the widget:
         my ($width, $height) = $canvas->size;
         my $x = sequence($width);
         my $y = ( sin($x / 20) + 1 ) * $height/2;
         $canvas->pdl_polylines($x, $y, lineWidths => 2);
         
         ### Example code ends here ###
     },
     backColor => cl::White,
 );
 
 run Prima;

=head1 DESCRIPTION

This module provides a number of PDL-threaded functions and bindings for use
with the Prima toolkit. Many of the functions are PDL bindings for the
standard Prima drawing functions. Others are useful functions for color
manipulation, or getting data into a form that PDL knows how to handle.
I generally divide the subroutines of this module into two categories:
B<methods> and B<functions>. The methods are subroutines that operate on a
Prima widget; the functions are subroutines that act on or return piddles.

Most of the methods given here are PDLified versions of the Prima drawing API
functions, which are documented under L<Prima::Drawable>. In general, where the
Prima API uses singular nouns, I here use plural nouns. A few of the methods
are only available in this module, mostly added to accomodate the needs of
L<PDL::Graphics::Prima>, the plotting library built on these bindings.

At the moment, only drawing on displayed widgets is supported. However, I
believe it is possible to revise these bindings with only a few
modifications to get them to work on any Prima::Drawable object. Hopefully
those revisions will happen soon.

=head1 COORDINATE ORIGIN

The Prima image coordinate origin is located in lower left corner, which is
where you would expect to find it when creating plots. However, it is different
from the way that many graphics libraries do their coordinates.

=head1 FUNCTIONS

=head2 piddle_of_patterns_for

If you want PDL to thread over line patterns, but you want to use the standard
Prima line patterns, you'll need to convert them line patterns to a piddle.
This works very simply like this:

 my $patterns = piddle_of_patterns_for(lp::Solid, lp::Dash);

This creates a piddle with the two patterns so that you could have PDL thread
over them.

You can also create your own line pattern piddles by hand. I recommend you use
byte array, since otherwise it will be converted to byte arrays for you.
The first element of a row in your byte array
specifies the number of pixels to be "on", the second specifies the number to be
"off", the third specifies the number to be "on" again, the fourth "off", the
fifth "on", etc. If that doesn't make sense, hopefull a couple of examples will
help clarify.

This example creates the equivalent of lp::Dash:

 my $dash_pattern = byte (9, 3);

This example creates a piddle with four line types: lp::Solid, lp::Dash,
lp::ShortDash, and lp::DashDot:
 
 my $patterns = byte q[ 1; 9 3; 3 3; 9 3 1 3];

and should be identical to

 my $patterns = piddle_of_patterns_for(
     lp::Solid, lp::Dash, lp::ShortDash, lp::DashDot);
 
When you create a byte piddle, all of the patterns must have the same number of
bytes in their specification. Of course, different patterns have different
lengths, so in that case simply pad the shorter specifications with zeroes.

=cut

# Builds a piddle of patterns with the appropriate sizes, etc.
sub piddle_of_patterns_for {
	# Make sure they're not being stupid:
	croak("You must supply at least one pattern to make a pattern piddle")
		if @_ == 0;

	# First get the longest pattern:
	my $length = 0;
	foreach(@_) {
		$length = length($_) if $length < length($_);
	}
	
	use PDL::NiceSlice;
	
	# Create the new byte array with the appropriate dimensions:
	my $to_return = zeroes(byte, $length, scalar(@_));
	$to_return .= $to_return->sequence;
	for (my $i = 0; $i < @_; $i++) {
		# Get a slice and update it:
		my $slice = $to_return(:,$i);
		substr ${$slice->get_dataref}, 0, length($_[$i]), $_[$i];
		
		# Make sure the modifications propogate back to the original:
		$slice->upd_data;
	}
	
	no PDL::NiceSlice;
	
	return $to_return;
}

=head2 piddle_of_handles_for

You can call a single drawing function on multiple widgets and have PDL
thread over the widgets for you. Why would anyone ever want to do that, you
ask? The only reason I can imagine is if somebody wanted to create a new
set of widget skins, in which case you'd want to call the same drawing
function on various widgets (with various parameters, obviously). Will this
ever happen in practice? Probably not, but if I can come up with a use case,
I'm sure somebody else can come up with a different use case, so I've
implemented it.

When you call C<piddle_of_handles_for>, you get back a PDL_LongLong piddle. The
values returned are the actual integer values used as the handles to the
widgets, i.e. they are pointers, which means you B<SHOULD NOT MODIFY THEM>
or you will almost certainly get a segmentation fault. I believe there is
a way to mark a piddle as read-only, but I'm not quite sure how to do that.

=cut

sub piddle_of_handles_for {
	# Make sure they're not being stupid:
	croak("You must supply at least one widget from which to get a handle")
		if @_ == 0;
	
	# Make sure all of the variables are indeed widgets:
	foreach(@_) {
		croak("One or more of your widgets does not seem to be descended from Prima::Drawable")
			unless blessed($_) and $_->isa('Prima::Drawable');
	}
	
	# Make a piddle large enough to hold the handles:
	my $to_return = zeroes(longlong, scalar(@_));
	
	# put the handles in the piddle:
	_piddle_of_handles_for(${$to_return->get_dataref}, @_);
	
	# Update the piddle and return it:
	$to_return->upd_data;
	return $to_return;
}

ModuleMaterial

pp_addxs('', q{
void
_piddle_of_handles_for(SV * piddle_SV, ...)
	CODE:
		int i;
		/* Get at the piddle's actual data array */
		long long * piddle = (long long*)SvPVX(piddle_SV);
		/* Fill the array with the handle values */
		for (i = 1; i < items; i++) {
			piddle[i-1] = (long long) gimme_the_mate(ST(i));
		}

});


pp_addpm({At=>'Top'},<<'ModuleMaterial');

=head1 METHODS

The methods described below are a bit unusual for PDL functions. First, they are
not actually PDL functions at all but are methods for C<Prima::Drawable>
objects. Second, their signatures will look a bit funny. Don't worry too much
about that, though, because they will resemble normal signatures close enough
that you should be able to understand them, I hope.

=cut

ModuleMaterial

=for details
As far as I can tell, PDL::PP only defines the '_<func>_int' form of a function
when you specify a PMCode in the pp_def. I can't figure out where this happens
in PP.pm, but that appears to be the output behavior.

=cut

pp_add_boot q{
	/* Initialize the Drawable virtual method table pointer, which is declared
	 * below and used to detect if the widget supports direct calls using the
	 * apricot graphics drawing functions. */
	CDrawable = (PDrawable_vmt)gimme_the_vmt( "Prima::Drawable");
};

pp_addhdr(pp_line_numbers(__LINE__ + 1, <<'HEADER'));

/* apricot is the (strangely named) header file that contains all of the
 * cross-platform functions. */

#undef WORD
#include <apricot.h>
#include <math.h>

/* working here - is this cross-platform? */
#define my CDrawable(widget_handle)
#include <generic/Drawable.h>

/* The virtual method table for Drawable objects, which I need for the
 * introspection in the POINT methods below */
PDrawable_vmt CDrawable;

/* get_size requires this dummy variable */
Point Point_buffer;

#define DECLARE_POINT_DATA													\
	Point * points_to_plot;													\
	AV * array_to_plot;														\
	SV ** array_elem_p

#define INIT_POINT_DATA														\
	do {																	\
		points_to_plot = 0;													\
		array_to_plot = 0;													\
		array_elem_p = 0;													\
	} while(0)

#define ENSURE_POINT_STORAGE(function, n_points)							\
	do {																	\
		if (my-> function == CDrawable-> function) {						\
			/* This is the direct raster drawing, so make sure we have */	\
			/* memory allocated for points_to_plot 						*/	\
			if (points_to_plot == 0) Newx(points_to_plot, n_points, Point);	\
		}																	\
		else {																\
			/* This is the Perl-level drawing, so make sure we have an AV */\
			/* and then ensure it is long enough */							\
			if (array_to_plot == 0) array_to_plot = newAV();				\
			av_fill(array_to_plot, (n_points) * 2);							\
		}																	\
	} while(0)

#define FREE_POINT_STORAGE													\
	do {																	\
		if (points_to_plot != 0) Safefree(points_to_plot);					\
		points_to_plot = 0;													\
		if (array_to_plot != 0) av_undef(array_to_plot);					\
		array_to_plot = 0;													\
	} while (0)

#define ADD_POINT(function, index, xval, yval)								\
	do {																	\
		if (my-> function == CDrawable-> function) {						\
			points_to_plot[index].x = xval;									\
			points_to_plot[index].y = yval;									\
		}																	\
		else {																\
			/* Add the x value */											\
			array_elem_p = av_fetch(array_to_plot, 2*(index), 1);			\
			if (array_elem_p == 0) {										\
				FREE_POINT_STORAGE;											\
				barf("Internal error: could not access Perl array element");\
			}																\
			sv_setnv(*array_elem_p, xval);									\
																			\
			/* Add the y value */											\
			array_elem_p = av_fetch(array_to_plot, 2*(index)+1, 1);			\
			if (array_elem_p == 0) {										\
				FREE_POINT_STORAGE;											\
				barf("Internal error: could not access Perl array element");\
			}																\
			sv_setnv(*array_elem_p, yval);									\
		}																	\
	} while(0)

#define DRAW_POINTS(function, apricot_function, n_to_plot)					\
	do {																	\
		if (my-> function == CDrawable-> function) {						\
			/* Call apricot's function */									\
		/*	printf("Drawing %s\n", #function);	*/							\
			apricot_function (widget_handle, n_to_plot, points_to_plot);	\
		}																	\
		else {																\
			/* Trim the array, in case any values were nan and therefore */	\
			/* skipped */													\
			av_fill(array_to_plot, 2*(n_to_plot) - 1);						\
			/* working here - should I just use newRV? */					\
			my-> function (widget_handle, newRV_noinc((SV*)array_to_plot));	\
		}																	\
	} while(0)


/* This is based on Prima's maximum coordinate size, which is 16383. I have
 * reduced it in order to accomodate certain coordinate transforms that Prima
 * performs:  */
#define MY_BIG_NUMBER 16000



/* Apricot uses some pretty dumb methods for correcting values that are too big.
 * The way it handles values clashes with the sheer range of values that I want
 * to be able to display, so I need to adjust those values somehow. The next
 * struct and 250 lines of code examines pairs of values for nan, inf, and
 * exceedingly large values. If the data cannot be drawn as-is, it calculates
 * values that can be drawn instead or indicates if the calling routine should
 * simply skip the values. */

typedef struct {
	/* two pairs under consideration */
	double x1;
	double x2;
	double y1;
	double y2;
	
	/* Temporary storage */
	double tmp_xs[2];
	double tmp_ys[2];
	int offset;
	
	/* Dimensions of the widget */
	int width;
	int height;
} big_number_container;

/* I use these functions within the real function, which is the first one that
 * is actually defined below. */
int is_inf(double val);
int is_nan(double val);
int _too_many_bad_values(big_number_container * d);
int _is_drawable_as_is(big_number_container * d);
void _check_start_within_bounding_box(big_number_container * d);
void _handle_horizontal_line(big_number_container * d);
void _handle_vertical_line(big_number_container * d);
void _check_crosses_left_edge(big_number_container * d, double y0, double slope);
void _check_crosses_bottom_edge(big_number_container * d, double y0, double slope);
void _check_crosses_right_edge(big_number_container * d, double y0, double slope);
void _check_crosses_top_edge(big_number_container * d, double y0, double slope);
void _check_cross_error (big_number_container * d);
void _set_returns_preserving_order (big_number_container * d);

/* Name    : _check_for_big_numbers
 * Expects : a pointer to the just-defined struct in which (x1, y1) and (x2, y2)
 *         : are the pars of points under consideration.
 * Returns : 0 when line should not be drawn
 *         : 1 when points are good as-is
 *         : 2 when points within the struct have been updated
 */

int _check_for_big_numbers(big_number_container * d) {
	/* Sanity check, make sure the width and height are reasonable */
	if (d->width > MY_BIG_NUMBER) {
		PerlIO_printf(PerlIO_stderr(), "Internal error in _check_for_big_numbers:\n");
		PerlIO_printf(PerlIO_stderr(), "  Found impossibly large width %d\n"
			, d->width);
		d->width = MY_BIG_NUMBER;
	}
	if (d->height > MY_BIG_NUMBER) {
		PerlIO_printf(PerlIO_stderr(), "Internal error in _check_for_big_numbers:\n");
		PerlIO_printf(PerlIO_stderr(), "  Found impossibly large height %d\n"
			, d->height);
		d->height = MY_BIG_NUMBER;
	}
	
	/* This line cannot be drawn if it is strictly above, below, to the left, or
	 * to the right of the view box */
	if (d->x1 < 0 && d->x2 < 0 || d->x1 > d->width && d->x2 > d->width
			|| d->y1 < 0 && d->y2 < 0 || d->y1 > d->height && d->y2 > d->height)
		return 0;
	
	if (_too_many_bad_values(d)) return 0;
	if (_is_drawable_as_is(d)) return 1;

	/* If we are here, we must take corrective measures. Find if any part of the
	 * line actually falls within the box, and figure out where it enters or
	 * leaves. */
	d->offset = 0;
	
	_check_start_within_bounding_box(d);
	
	/* Before we go further, check for horizontal or vertical lines. */
	if (d->y1 == d->y2 || is_inf(d->x1) || is_inf(d->x2))
		_handle_horizontal_line(d);
	else if (d->x1 == d->x2 || is_inf(d->y1) || is_inf(d->y2))
		_handle_vertical_line(d);
	else {
		/* We have a line with a slope. See which boundaries it crosses, if any.
		 * Note that the order of the checks is very important as some of the
		 * inequalities are strict and others are not. */

		double slope = (d->y2 - d->y1) / (d->x2 - d->x1);
		double y0 = d->y1 - slope * (d->x1);
		_check_crosses_left_edge(d, y0, slope);
		_check_crosses_bottom_edge(d, y0, slope);
		_check_crosses_right_edge(d, y0, slope);
		_check_crosses_top_edge(d, y0, slope);
		_check_cross_error(d);
		
		/* At this point, if the offset is not 2, the line does not intersect
		 * the view box, so the line will not be drawn and we can return 0 to
		 * indicate that. */
		if (d->offset != 2) return 0;
	}
	
	_set_returns_preserving_order(d);
	return 2;
}

/* Determines if a number of infinite; assumes it is *not* nan */
int is_inf(double v) {
	return (v * 0.0 != 0.0);
}

int is_nan(double v) {
	return v != v;
}

/* checks for nan and inf. */
int _too_many_bad_values(big_number_container * d) {
	/* One nan is one too many */
	if (d->x1 != d->x1 || d->x2 != d->x2 || d->y1 != d->y1 || d->y2 != d->y2)
		return 1;
	
	/* This line should be skipped if two or more of its values are inf */
	int inf_count = 0;
	if (is_inf(d->x1)) inf_count++;
	if (is_inf(d->x2)) inf_count++;
	if (is_inf(d->y1)) inf_count++;
	if (is_inf(d->y2)) inf_count++;
	if (inf_count > 1) return 1;
	
	return 0;
}

/* Checks if the values are within Prima's limits. This *MUST* not be called
 * before _too_many_bad_values!!! */
int _is_drawable_as_is(big_number_container * d) {
	if (		-MY_BIG_NUMBER <= d->x1 && d->x1 <= MY_BIG_NUMBER
			&&	-MY_BIG_NUMBER <= d->y1 && d->y1 <= MY_BIG_NUMBER
			&&	-MY_BIG_NUMBER <= d->x2 && d->x2 <= MY_BIG_NUMBER
			&&	-MY_BIG_NUMBER <= d->y2 && d->y2 <= MY_BIG_NUMBER)
		return 1;
	return 0;
}

void _check_start_within_bounding_box(big_number_container * d) {
	/* Does this line start within the bounding box? */
	if (d->x1 >= 0 && d->x1 <= d->width && d->y1 >= 0 && d->y1 <= d->height) {
		d->tmp_xs[0] = d->x1;
		d->tmp_ys[0] = d->y1;
		d->offset++;
	}
	/* or does it end within the bouding box? */
	else if (d->x2 >= 0 && d->x2 <= d->width && d->y2 >= 0 && d->y2 <= d->height) {
		d->tmp_xs[0] = d->x2;
		d->tmp_ys[0] = d->y2;
		d->offset++;
	}
}

void _handle_horizontal_line(big_number_container * d) {
	/* Did the line start or end in the box? */
	if (d->offset == 1) {
		/* Yes, so replace the other coordinate with the box's bound. */
		d->tmp_ys[1] = is_inf(d->x1) ? d->y2 : d->y1;
		if (d->x1 < 0 || d->x2 < 0)				d->tmp_xs[1] = 0;
		if (d->x1 > d->width || d->x2 > d->width)	d->tmp_xs[1] = d->width;
		d->offset++;
	}
	else {
		/* No, so set the coordinates to the box's bound at the same y */
		d->tmp_xs[0] = 0;
		d->tmp_xs[1] = d->width;
		d->tmp_ys[0] = d->tmp_ys[1] = is_inf(d->x1) ? d->y2 : d->y1;
		d->offset += 2;
	}
}

void _handle_vertical_line(big_number_container * d) {
	/* Did the line start or end in the box? */
	if (d->offset == 1) {
		/* Yes, so replace the other coordinate with the box's bound */
		d->tmp_xs[1] = is_inf(d->y1) ? d->x2 : d->x1;
		if (d->y1 < 0			|| d->y2 < 0)			d->tmp_ys[1] = 0;
		if (d->y1 > d->height	|| d->y2 > d->height)	d->tmp_ys[1] = d->height;
		d->offset++;
	}
	else {
		/* No, so set the coordinates to the box's bound at the same x */
		d->tmp_xs[0] = d->tmp_xs[1] = is_inf(d->y1) ? d->x2 : d->x1;
		d->tmp_ys[0] = 0;
		d->tmp_ys[1] = d->height;
		d->offset += 2;
	}
}

void _check_crosses_left_edge(big_number_container * d, double y0, double slope) {
	/* Does this line cross the vertical line x = 0? */
	if ((d->x1 < 0 || d->x2 < 0) && y0 >= 0 && y0 <= d->height) {
		d->tmp_xs[d->offset] = 0;
		d->tmp_ys[d->offset] = y0;
		d->offset++;
	}
}

void _check_crosses_bottom_edge(big_number_container * d, double y0, double slope) {
	/* Can't cross bottom if both positive */
	if (d->y1 > 0 && d->y2 > 0) return;
	
	double x0 = -y0 / slope;
	/* x == 0 was handled by the left edge check, so this only succeeds if x0 is
	 * strictly greater than zero. */
	if (x0 > 0 && x0 <= d->width) {
		d->tmp_xs[d->offset] = x0;
		d->tmp_ys[d->offset] = 0;
		d->offset++;
	}
}

void _check_crosses_right_edge(big_number_container * d, double y0, double slope) {
	/* Can't cross right edge if both x values are less than it */
	if (d->x1 < d->width && d->x2 < d->width) return;
	
	double y_r = y0 + slope * d->width;
	/* Note, y == 0 was handled by the bottom edge check, so this only succeeds
	 * if  yr is strictly greater than zero. */
	if (y_r > 0 && y_r <= d->height) {
		d->tmp_xs[d->offset] = d->width;
		d->tmp_ys[d->offset] = y_r;
		d->offset++;
	}
}

void _check_crosses_top_edge(big_number_container * d, double y0, double slope) {
	/* Can't cross the top edge if both y values are less than it */
	if (d->y1 > d->height && d->y2 > d->height) return;
	
	double x_t = (d->height - y0) / slope;
	/* Note, x == 0 and x == width were handled above, so this checks for
	 * strict inequality */
	if (x_t > 0 && x_t < d->width) {
		d->tmp_xs[d->offset] = x_t;
		d->tmp_ys[d->offset] = d->height;
		d->offset++;
	}
}

void _check_cross_error (big_number_container * d) {
	/* Spew a message if there is one or three intersection points, as that
	 * should never occurr and indicates an internal error. */
	if (d->offset == 1 || d->offset > 2) {
		PerlIO_printf(PerlIO_stderr(), "Internal error in _check_for_big_numbers:\n");
		PerlIO_printf(PerlIO_stderr(), "  offset should be 0 or 2, but it is %d\n"
			, d->offset);
		PerlIO_printf(PerlIO_stderr(), "  x1=%f, y1=%f, x2=%f, y2=%f, width=%d, height=%d\n"
			, d->x1, d->y1, d->x2, d->y2, d->width, d->height);
	}
}

void _set_returns_preserving_order (big_number_container * d) {
	/* This only gets called when it's time to change x1, x2, y1, and y2.
	 * Set them to the values in the temporary array, but take care to
	 * preserve the original ordering. */
	if (	d->x1 != d->x2 && ((d->x1 < d->x2) == (d->tmp_xs[0] < d->tmp_xs[1]))
		||	d->y1 != d->y2 && ((d->y1 < d->y2) == (d->tmp_ys[0] < d->tmp_ys[1])))
	{
		d->x1 = d->tmp_xs[0];
		d->x2 = d->tmp_xs[1];
		d->y1 = d->tmp_ys[0];
		d->y2 = d->tmp_ys[1];
	}
	else {
		d->x1 = d->tmp_xs[1];
		d->x2 = d->tmp_xs[0];
		d->y1 = d->tmp_ys[1];
		d->y2 = d->tmp_ys[0];
	}
}

HEADER

#######################################################################
#                              Machinery                              #
#######################################################################

=begin details

=head1 Complex parameter handling

Each of the functions in this module wrap a PDL function around the
Prima API. The goal of the PDL functions is to allow the caller to
provide as many or as few tweaks to their drawing as they wish, so if
they want to draw three different polylines with three different line
styles (as demonstrated in test.pl), they should be able to do this:

 $widget->pdl_polylines($xs, $ys, {linePatterns => $patterns});

and it will DWIM. That means that the PP functions have to (1) get all
the possible preferences in as parameters (preferably piddles), (2) the
PP functions have to call the appropriate functions from apricot.h
to do their work, and (3) the PP functions have to package their piddles
in a form that the apricot.h functions know how to handle. To make
matters even more complicated, different API functions pay attention to
different properties, so different ones apply for different functions!

To deal with all of this, the next 400 or so lines of code create some
machinery that greatly assists in building the pp_defs that follow. A
great deal of this code is used in THIS script (.pd files are actually
scripts that generate .xs and .pm files) to assist in generating code.
Anything that needs to end up in the *output* files will be quoted, so
hopefully your syntax highlighter will help you pick them apart.

=end details

=cut

###################################################
# Creating the look-up table for the Pars section #
###################################################

=begin details

This hash translates from a simple parameter name to a PDL signature.
Without this hash, if I wanted to write a function that allows the user
to draw lines with different colors, I would write the following Pars:

  Pars => 'int x(n); int y(n); int colors()'

So in the hash below, the property C<colors> is associated with the
arg string C<int colors()>, and (not-optional, but specially processed)
C<handles> property is associated with the arg string C<longlong handles()>.
(longlong is necessary here so that the integer data type is large enough to
hold 64-bit pointer addresses.)

=end details

=cut

my %pars_args_for = (colors => 'int colors()'
	, handles => 'longlong handles()'
);

=begin details

At the moment, I only have the colors property. If you know the Prima
Drawable API, you'll know I'm missing a lot! This is because I will
build up a number of structures over this discourse and I would
like to keep the code and specifications for each property in one place.
Scroll down to the 'Assembling machinery' portion of this code, about
175 lines below, and you'll see all the parts for each of the Drawable
properties defined in one place.

=end details

=cut

#########################
# Generating Pars lists #
#########################

=begin details

This function creates a string with the low-level PDL function's argument
list, given a list of properties for the function. This makes it very
easy to manage long parameter lists, and long parameter lists are nicely
handled by the in-pm function C<get_sorted_args_with_defaults>. It also
adds handles to the signature, which is mandatory for each of these
functions. To expand on the previous example, in this code:

 pp_def('my_func',
        Pars => 'int x(n); int y(n); ' . generate_pars_args_for( 'colors', 'rops'),
        ...
 );

pp_def sees a parameter list that looks like this:

 'int x(n); int y(n); longlong handles(); int colors(); int rops()'

To use this, I will create a list of properties that the to-be-defined
function takes, and use that together with generate_pars_args_for like
so:

 my @clear_properties = qw(backColors rop2s);
 pp_def('prima_clear',
        Pars => 'int x1(); int y1(); int x2(); int y2(); '
                 . generate_pars_args_for(@clear_properites),
        PMCode => ...
 );

It may seem silly to use such an array for only two additional arguments
(as shown in this example), but other parts of the pp_def call will make
use of that array, as we will see, and most of the functions use many
more properties.

=end details

=cut

sub generate_pars_args_for {
	foreach (@_) {
		croak("Bad args; should be plural") unless /s$/;
	}
	return join('; ', @pars_args_for{'handles', @_});
}

######################################
# Property-dependent local variables #
######################################

=begin details

As already mentioned, many of the properties that could potentially be
sent to the drawing apricot.h functions will need a set of local
variables. Currently, clipRects and linePatterns need special variables
to do their work, and these variables should be created outside the
threadloop. (regions, when implemented, may need to use this, too.)
Functions that do not care about those properties will not need those
variables, so they should only be included in functions that actually
use them. generate_init_args_for handles this code generation, taking
the same array of properties used by generate_pars_args_for. See the
next section for an example of use.

Note that entries in C<%init_args_for> should be semi-colon seperated,
since they are C declarations, but the last entry should not have a 
semi-colon. One will be appended. This is to keep consistency with
C<%pars_args_for>, which has the same format.

=end details

=cut

my %init_args_for = ();

sub generate_init_args_for {
	my $to_return = "\t\t/* These are declarations needed for the handles
		 * and some of the optional parameters */
		 Handle widget_handle;\n";
		 
	# Build the list:
	foreach(@_) {
		$to_return .= "\t\t$init_args_for{$_};\n"
			if exists $init_args_for{$_};
	}
	
	return $to_return;
}

##########################################
# Tracking which properties need setting #
##########################################

=begin details

The only way to determine from within PP code whether an optional parameter
was passed in or not is to pass an additional structure to the PP code with
that information. The structure I use for this is the original hash passed
in as an argument to the Perl-level function. If the user specified a value
for a property, it will be present in the hash. If they did not, it will not
be there.

So, for each of the graphics properties that the user can supply for a given
function, I will want to have code in the PP Code section that looks
something like this:

 int is_setting_rops;
 is_setting_rop = hv_exists(arg_hash_hv, "rops", 4);

This code checks if the key "rops" exists in the arg_hash_hv hash (which
must be passed in to the PP function via OtherPars). The
return value is a boolean, which I will use in the threadloop. Looking
up these values once and storing their results will make the resulting
code much less cluttered, and hopefully faster.

Here's a function that generates the code for me, based on the supplied
list of properties. It's a little different from the example above, but
they basically do the same thing. It, too, uses the same array of
properties used by generate_pars_args_for. The auto-generated code from
this function is inserted directly into the Code key in the pp_def
function call, like so:

 my @func_pars = qw(backColor linePattern);
 pp_def('my_func',
     Pars => 'int arg1(n); ' . generate_pars_args_for(@func_pars),
     ...
     Code => q{
         /* set-up variables I will need throughout the threadloop */
         int alpha;
     } . generate_init_args_for(@func_pars)
       . create_boolean_setters_for(@func_pars)
     . q{
         alpha = -1;
         ... 
         threadloop %{
             ...
         %}
     },

=end details

=cut

sub create_boolean_setters_for {
	# Make sure I handle an empty list correctly. I can't imagine
	# calling this function with an empty list, but let's be safe:
	return '' unless @_;
	# This is the string I will build up for my return value:
	my $to_return = "
		/* The last of the declarations */
		HV* arg_hash_hv;
		int ";
	# Create the variable list (is_setting_colors, is_setting_lineWidths...):
	$to_return .= join(', ', map {"is_setting_$_"} @_) . ";\n";
	
	# Set the variables:
	$to_return .= "
		/* Begin initializing the values */
		arg_hash_hv = (HV*)SvRV(\$COMP(arg_ref_sv));
";
	foreach(@_) {
		$to_return .= "\t\tis_setting_$_ = hv_exists(arg_hash_hv, \"$_\", "
					. length($_) . ");\n";
	}
	return $to_return;
}

####################################
# Creating the initialization code #
####################################

=begin details

I've built up a lot of machinery to handle the various required arguments
and optional properties. This next chunk of code gives a single function
that will call everything in the proper order to declare and initialize
the necessary variables, early within the Code section.

=end details

=cut

sub initialize_for {
	my @properties = @_;
	return '
		/* BEGIN AUTOGENERATED INITIALIZATION */

	' . generate_init_args_for(@properties)
	  . create_boolean_setters_for(@properties) . '
		
		/* END AUTOGENERATED INITIZLIATION */
	';
}

my $default_other_pars = 'SV * arg_ref_sv';

#######################
# Calling the setters #
#######################

=begin details

Each of the setters needs to first check if its call is even necessary
(using the boolean variables set-up in the previous section),
and then it needs to call the appropriate setter from apricot.h. This is
easy but repetitive code, so once again I generate it from the same
list of arguments as everything else. In what follows, I create a
function that generates these code fragments for me, or looks them up
in a hash if they're complicated. Note that the function wraps the
looked-up code in its own curly-braced block; all you need to write is
the code itself like the following colors example shows:

The auto-generated code for this section is inserted directly into the
Code key in the pp_def function call, within the threadloop, before the
apricot function for this function is itself called. For example:

 q[
     ...
     threadloop %{
		 /* Apply any per-threadloop tweaks */
         ] . generate_setter_code_for(@func_pars)
         . q[
         /* Call the apricot function */
         my->set_func(args);
     %}
 ]

=end details

=cut

my %set_code_for = (
	colors => pp_line_numbers (__LINE__, q{
				/* cast the integer as a Colors type (which itself is a
				 * 32-bit int, so maybe this is unnecessary */
				my->set_color(widget_handle, (Color)$colors());
	}),
);

sub generate_single_setter_code_for {
	my $property = shift;
	# Make the singular name from the plural:
	(my $singular = $property) =~ s/s$//;
#	# apricot uses underscores and all lowercase instead of CamelCase:
#	(my $apricot  = $singular) =~ s/([A-Z])/_\l$1/g;
	# Build the return string:
	my $to_return = "\t\t\tif (is_setting_$property) {\n";
	if (exists $set_code_for{$property}) {
		# Insert special handling code:
		$to_return .= $set_code_for{$property};
	}
	else {
		# Most other properties are direct sets:
		$to_return .= "\t\t\t\tmy->set_$singular(widget_handle, \$$property());\n";
	}
	
	$to_return .= "\t\t\t}";
}

# working here - I think I need to create a hash like %bad_check_code_for
# to handle per-property bad checking code
sub generating_bad_single_setter_code_for {

}

sub generate_setter_code_for {
	return "
			widget_handle = (Handle)\$handles();
			/* BEGIN AUTOGENERATED SETTER CHECKS */\n"
			. join("\n", (map {generate_single_setter_code_for($_)} @_)) . "
			/* END AUTOGENERATED SETTER CHECKS */\n";
}

#############################
# Per-Property Cleanup Code #
#############################

=begin details

At least one of the properties allocates memory that must be freed when we're
done.

=end details

=cut

# colors does not need any special cleanup code:

my %cleanup_code_for = ();

sub generate_cleanup_code_for {
	my $to_return = '
		/* BEGIN AUTOGENERATED CLEANUP CODE */
		
';
	foreach (@_) {
		$to_return .= $cleanup_code_for{$_} if exists $cleanup_code_for{$_};
	}
	return $to_return . '
		
		/* END AUTOGENERATED CLEANUP CODE */
';
}

##################################################
# Building machinery for the different properies #
##################################################

=begin details

Now that I have all of the infrastructure ready, I need to build up the
data structures for each of the properties.

=end details

=cut

# Background color:
$pars_args_for{backColors} = 'int backColors()';
$set_code_for{backColors} = pp_line_numbers(__LINE__, q{
				/* cast the integer as a Colors type (actually an int) */
				my->set_backColor(widget_handle, (Color)$backColors());
});

# Clipping rectangle:
$pars_args_for{clipRects} = 'int clipLeft(); int clipBottom(); int clipRight(); int clipTop()';
$init_args_for{clipRects} = 'Rect clip_rect';
$set_code_for{clipRects} = pp_line_numbers(__LINE__, q{
				clip_rect.left = $clipLeft();
				clip_rect.bottom = $clipBottom();
				clip_rect.right = $clipRight();
				clip_rect.top = $clipTop();
				my->set_clipRect(widget_handle, clip_rect);
});

# These do not need any special args, and the default generated code will
# work just fine:
$pars_args_for{lineEnds} = 'int lineEnds()';
$pars_args_for{lineJoins} = 'int lineJoins()';
$pars_args_for{lineWidths} = 'int lineWidths()';
$pars_args_for{rops} = 'int rops()';
$pars_args_for{rop2s} = 'int rop2s()';

# line patterns. This code has to cast the byte piddle into a char and
# send that and the length to the line_pattern function.
$pars_args_for{linePatterns} = 'byte linePatterns(patlen)';
$init_args_for{linePatterns} = 'SV * pattern';
$set_code_for{linePatterns} = pp_line_numbers(__LINE__, q{
				/* Copy the pattern to a Perl scalar */
				pattern = newSVpv((unsigned char *)$P(linePatterns), 0);
				my->set_linePattern(widget_handle, pattern);
});

# translation; the apricot function for translate uses a different name
# and takes two arguments instead of one:
$pars_args_for{translates} = 'int trans_x(); int trans_y()';
$init_args_for{translates} = 'Point tr';
$set_code_for{translates} = pp_line_numbers(__LINE__, q{
				/* Set tr and then use it to set the translate */
				tr.x = $trans_x();
				tr.y = $trans_y();
				my->set_translate(widget_handle, tr);
});

# Fill winding works nicely without any alteration:
$pars_args_for{fillWindings} = 'byte fillWindings()';

# Fill pattern requires that we pack the pattern into an 8x8 Perl array.
# Kinda stupid, but oh well, what can we do?
$pars_args_for{fillPatterns} = 'byte fillPatterns(oct=8)';
$init_args_for{fillPatterns} = pp_line_numbers(__LINE__, q{
			AV * fill_av = newAV();
			SV * fill_ref_sv = newRV_noinc((SV*)fill_av);
			AV * tmp_fill_av;
			SV * tmp_fill_sv;
			/* Ensure there are eight rows */
			av_fill(fill_av, 7);
			
			/* Ensure that each row has eight columns */
			int av_i, av_j;
			for (av_i = 0; av_i < 8; av_i++) {
				tmp_fill_av = newAV();
				av_fill(tmp_fill_av, 7);
				av_store(fill_av, av_i, (SV*)tmp_fill_av);
			}
});
$set_code_for{fillPatterns} = pp_line_numbers(__LINE__, q{
			/* Copy the fill pattern into the array */
			for (av_i = 0; av_i < 8; av_i++) {
				tmp_fill_av = (AV*)*(av_fetch(fill_av, av_i, 1));
				for (av_j = 0; av_j < 8; av_j++) {
					tmp_fill_sv = *(av_fetch(tmp_fill_av, av_j, 1));
					sv_setiv(tmp_fill_sv, (((1<<av_j) & $fillPatterns(oct => av_j)) >> av_j));
				}
			}
			
			/* Set the fill pattern */
			my->set_fillPattern(widget_handle, fill_ref_sv);
});
$cleanup_code_for{fillPatterns} = pp_line_numbers(__LINE__, q{
		/* I will never return these, so I will unconditionally free their memory */
		av_undef(fill_av);
		sv_2mortal(fill_ref_sv);
});

# Spline precision works well with the default setup:
$pars_args_for{splinePrecisions} = 'int splinePrecisions()';

# Ignoring for now: region
# The underlying graphics functions explicitly operate with a 1-bit-per-pixel
# Prima::Image bitmap. I could use PDL::PrimaImage as the argument, but
# that seems like a lot of repackaging for every round in the PP
# threadloop. Alternatively, I could take an array ref with Prima::Image
# objects as the argument, and simply cycle through that.


#######################################################
# Argument processing, ordering, and default handling #
#######################################################

=begin details

Each of the perl-side functions that gets invoked as an object
method checks its arguments. It does this by analyzing the hash sent in
by the caller, checking for properties that don't belong, or were
mis-spelled, and repackaging the results into a list with the exact
order needed by the PP code. Most parameters take a single piddle as
their argument, but some don't. This code needs to know how many
arguments go with each parameter, so it can check that, too. Such a list
of parameters can be automatically constructed from the already-defined
%pars_args_for hash.

=end details

=cut

pp_addpm (join("\n"
	, '# This is a list of the number of arguments for each property. It is based on the'
	, '# pars_args_for hash which is built in the .pd file associated with this module'
	, 'my %N_args_for = qw('
	# Note that the tr operator, as used, just counts the number of semi-colons
	# in the pars args associated with the property.
	, (map {sprintf "\t%-20s %d", $_, ($pars_args_for{$_} =~ tr/;//) + 1}
		(keys %pars_args_for))
	, ');'
	)
);

=begin details

Having collected the number of arguments associated with each of the
properties, I need a function to actually process the hash.
This is a function that I call in all of my PMCode sections. It takes an
anonymous list of names and an anonymous hash. If the hash has a key for
one of the names, it includes that in the return list. If it doesn't, it
returns the default value of a 0-dim piddle with a value corresponding to
the widget's handle. If one of the hash keys is not in the list of names,
it croaks.

Put a little differently, this function takes an anonymous hash, makes
sure there are no extraneous arguments, extracts the desired arguments
or uses a sensible default, and returns the arguments in the desired
order.

=end details

=cut

# working here - consider allowing singular as well as plural options.

pp_addpm <<'DefaultArgumentHandling';

sub get_sorted_args_with_defaults {
	my ($self, $arg_names, $given) = @_;
	
	# Default to an empty list:
	$given = {} unless ref($given) eq 'HASH';
	
	# Copy the arg_names array, so I can add 'handles' to it without
	# effecting the original array:
	my @arg_names = @$arg_names;
	unshift @arg_names, 'handles';
	
	# Check that they supplied only allowed parameters:
	foreach my $parameter (keys %$given) {
		croak("Unknown parameter $_")
			unless grep {$_ eq $parameter} @$arg_names
	}
	
	# Create a 0-dim piddle with this object's hande in it:
	my $handle = piddle_of_handles_for($self);
	
	# Return the sorted list of supplied or default values
	my @to_return = ();
	foreach ('handles', @$arg_names) {
		# If not specified, return a default property of a zero-dim
		# piddle. Except for the handles, the value doesn't matter
		# because it is never used. For handles, the value should revert
		# to the calling widget's handle:
		if (not exists $given->{$_}) {
			push @to_return, ($handle) for (1..$N_args_for{$_});
		}
		elsif (ref ($given->{$_}) eq 'ARRAY') {
			# If an array ref, dereference it and make sure the number
			# of arguments agrees with what we expect:
			if (@{$given->{$_}} != $N_args_for{$_}) {
				croak("Expected 1 argument for $_") if $N_args_for{$_} == 1;
				croak("Expected $N_args_for{$_} arguments for $_");
			}
			push @to_return, @{$given->{$_}};
		}
		else {
			# Otherwise, return it outright, if we only expected one
			# argument:
			$N_args_for{$_} == 1
				or croak("Expected $N_args_for{$_} arguments for $_");
			
			push @to_return, $given->{$_};
		}
	}
	return @to_return;
}

DefaultArgumentHandling


###################################
# Generating PMCode automatically #
###################################

=begin details

The PMCode section of each of these is pretty much the same. This
snippet of code generates that code for me. It takes the names of the
arguments and returns the autogenerated PMCode.

This code is very dense. I hope that it is documented well enough with
comments that any future maintainer will be able to understand it. If
in doubt, this function operates stand-alone, so you can copy it into
a little test script and try calling it with sample parameters to get a
feel for how it behaves.

working here - I have a few argument checking
ideas for this function, including
considering checking that C<$self> is a Prima::Drawable type, but not
Prima::PS::Drawable. Also, I bet if PDL barfs, it'll point to the line
in the (generated) pm file, so the pdl function call should probably be
wrapped in an eval block, and $@ should be post-processed.

=end details

=cut

sub generate_PMCode_for {
	my ($func_name, $props, @arg_names) = @_;
	my $props_array_name = '@' . $func_name . '_props';
	my $args_array_name = '@' . $func_name . '_args';
	# Outside the function definition, create the list of properties
	# that this function uses, as well as the names of the arguments.
	# It needs these lists in the actual Perl module file so it can
	# check the passed arguments and provide meaningful error messages:
	my $to_return = "our $props_array_name = qw(@$props);\n"
				. "our $args_array_name = qw(@arg_names);\n";
	
	# Define the drawable function in the Prima::Drawable namespace
	# and check for arguments:
	$to_return .= "sub Prima::Drawable::pdl_$func_name {
	# Before anything else, make sure they supplied at least the
	# required number of arguments:
	croak('pdl_$func_name expectes '. scalar($args_array_name)
		. ' arguments (and the widget): ' . join(', ', 'widget', $args_array_name))
		unless (\@_ > $args_array_name);

	# unpack the widget and the required arguments for this function:
";
	foreach ('self', @arg_names) {
			$to_return .= "\tmy \$$_ = shift;\n";
	}
	$to_return .= "
	# Check for an even number of remaining arguments (key-value pairs):
	croak('pdl_$func_name expects optional parameters as key => value pairs')
		unless \@_ % 2 == 0;
	
	my \%args = \@_;
	
	# Get the a full list of arguments suitable for the internal pp code
	# in the correct order:
	my \@args_with_defs
		= get_sorted_args_with_defaults(\$self, \\$props_array_name, \\\%args);

	# Call the PP'd internal code. Always put the args hash last.
	eval {
		PDL::_prima_${func_name}_int(";
	# include all the required arguments:
	foreach(@arg_names) {
		$to_return .= '$' . $_ . ', ';
	}
	# finish with self and the args list:
	$to_return .= '@args_with_defs, \%args);
	};
	
	if ($@) {
		# die $@;
		$@ =~ s/at (.*?) line \d+\.\n$//;
		croak "Issues calling pdl_' . $func_name . ': $@";
	}
	' . "\n}\n";
	 
	return $to_return;
}


#######################################################################
#                              Functions                              #
#######################################################################

=begin details

At last I begin the declaration of PP code. The idea behind all of this
machinary is that I declare a collection of applicable properties in
THIS SCRIPT, and then use that to generate consistent code blocks. I
even use the properties array to generate compile-time accurate
documentation, so the on-machine documentation can never go out-of-sync
with the on-machine library.

=end details

=cut

# working here - check this and all following for edge handling

##############
# prima_arcs #
##############

my @properties = qw(colors backColors lineEnds linePatterns lineWidths rops rop2s translates);
pp_def('prima_arcs',
	Pars => 'int x(); int y(); int x_diameter(); int y_diameter();
			start_angle(); end_angle(); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['D'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('arcs', \@properties, qw(x y x_diameter y_diameter start_angle end_angle)),
	Code => 
	# I don't need any extra variables for arcs, so I'll just add the
	# auto-generated declaration and initialization code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's arc function */
			my->arc(widget_handle, $x(), $y(), $x_diameter(),
				$y_diameter(), $start_angle(), $end_angle());
		%}
	])
	. generate_cleanup_code_for(@properties),
	Doc => q{

=head2 pdl_arcs

=for sig

  Prima Signature: (widget; x(); y(); x_diameter(); y_diameter();
                     start_angle(); end_angle(); properties)

=for ref

Draws arcs, i.e. incomplete ellipses.

The arcs go from the C<start_angle>s to the C<end_angle>s along the
ellipses centered at the C<x>s and C<y>s, with the specified x- and
y-diameters. The angles are measured in degrees, not radians.
The difference between this command and L</chords> or L</sectors> is that
C<arcs> does not connect the dangling ends.

Here's a simple example:

=for example

 # Draw a bunch of random arcs on $canvas:
 my $N_arcs = 20;
 my ($x_max, $y_max) = $canvas->size;
 my $xs = zeroes($N_arcs)->random * $x_max;
 my $ys = $xs->random * $y_max;
 my $dxs = $xs->random * $x_max / 4;
 my $dys = $xs->random * $y_max / 4;
 my $th_starts = $xs->random * 360;
 my $th_stops = $xs->random * 360;
 
 # Now that we've generated the data, call the command:
 $canvas->pdl_arcs($xs, $ys, $dxs
                , $dys, $th_starts, $th_stops);

If you put that snippet of code in the onPaint method, as
suggested in the synopsis, a completely new set of arcs will get
redrawn whenever you resize your window.


Compare to the Prima method L<Prima::Drawable/arc>. Closely related
routines include L</pdl_chords> and L</pdl_sectors>. See also
L</pdl_fill_chords>, and L</pdl_fill_sectors>, L</pdl_ellipses>, and
L</pdl_fill_ellipses>.

Spline drawing provides a similar functionality, though more complex and
more powerful. There are no PDL bindings for the spline functions yet.
See L<Prima::Drawable/spline> for more information.

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

"

);

=pod

Applicable properties are likely to include handles, colors, backColors,
lineEnds, linePatterns, lineWidths,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

##############
# prima_bars #
##############

@properties = qw(colors backColors clipRects fillPatterns rops rop2s translates);
pp_def('prima_bars',
	Pars => 'x1(); y1(); x2(); y2(); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['D'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('bars', \@properties, qw(x1 y1 x2 y2)),
	Code => 
	# I don't need any extra variables for bars, so I'll just add the
	# auto-generated declaration and initialization code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's bar function */
			my->bar(widget_handle, $x1(), $y1(), $x2(), $y2());
		%}
	])
	. generate_cleanup_code_for(@properties),
	Doc => q{

=head2 pdl_bars

  Prima Signature: (widget; x1(); y1(); x2(); y2(); properties)

=for ref

Draws filled rectangle from corner (x1, y1) to (x2, y2).

=for example

 # Draw 20 random filled rectangles on $canvas:
 my $N_bars = 20;
 my ($x_max, $y_max) = $canvas->size;
 my $x1s = zeroes($N_bars)->random * $x_max;
 my $y1s = $x1s->random * $y_max;
 my $x2s = $x1s + $x1s->random * ($x_max - $x1s);
 my $y2s = $y1s + $x1s->random * ($y_max - $y1s);
 my $colors = $x1s->random * 2**24;
 
 # Now that we've generated the data, call the command:
 $canvas->pdl_bars($x1s, $y1s, $x2s, $y2s
         , colors => $colors);

If you put that snippet of code in the onPaint method, as
suggested in the synopsis, a completely new set of filled rectangles
will get redrawn whenever you resize your window.

Compare to the Prima method L<Prima::Drawable/bar>. See also
L</pdl_rectangles>, which is the unfilled equivalent, and L</pdl_clears>,
which is sorta the opposite of this.

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
fillPatterns,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut


################
# prima_chords #
################
@properties = qw(colors backColors clipRects lineEnds linePatterns lineWidths rops rop2s translates);
pp_def('prima_chords',
	Pars => 'int x(); int y(); int x_diameter(); int y_diameter();
			start_angle(); end_angle(); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['D'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('chords', \@properties, qw(x y x_diameter y_diameter start_angle end_angle)),
	Code => 
	# I don't need any extra variables for chords, so I'll just add the
	# auto-generated declaration and initialization code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's chord function */
			my->chord(widget_handle, $x(), $y(), $x_diameter(),
				$y_diameter(), $start_angle(), $end_angle());
		%}
	])
	. generate_cleanup_code_for(@properties),
	Doc => q{

=head2 pdl_chords

  Prima Signature: (widget; x(); y(); x_diameter(); y_diameter();
                           start_angle(); end_angle(); properties)

=for ref

Draws arcs (i.e. incomplete ellipses) whose ends are connected by a line.

The chord starts at C<start_angle> and runs to C<end_angle> along the ellipse
centered at C<x>, C<y>, with their specified diameters C<x_diameter>,
C<y_diameter>. Unlike L</arcs> or L</sectors>, it connects
the ends of the arc with a straight line. The angles are
measured in degrees, not radians.

=for example

 # For this example, you will need:
 use PDL::Char;
 
 # Draw a bunch of random arcs on $canvas:
 my $N_chords = 20;
 my ($x_max, $y_max) = $canvas->size;
 my $xs = zeroes($N_chords)->random * $x_max;
 my $ys = $xs->random * $y_max;
 my $dxs = $xs->random * $x_max / 4;
 my $dys = $xs->random * $y_max / 4;
 my $th_starts = $xs->random * 360;
 my $th_stops = $xs->random * 360;
 
 # make a small list of patterns:
 my $patterns_list = PDL::Char->new(
          [lp::Solid, lp::Dash, lp::DashDot]);
 
 # Randomly select 20 of those patterns:
 my $rand_selections = ($xs->random * 3)->byte;
 use PDL::NiceSlice;
 my $patterns = $patterns_list($rand_selections)->transpose;
 
 # Now that we've generated the data, call the command:
 $canvas->pdl_chords($xs, $ys, $dxs
                , $dys, $th_starts, $th_stops
                , linePatterns => $patterns);

If you put that snippet of code in the onPaint method, as
suggested in the synopsis, a completely new set of chords
will get redrawn whenever you resize your window.

Compare to the Prima method L<Prima::Drawable/chord>. The filled
equivalent is L</pdl_fill_chords>. Closely related routines are
L</pdl_arcs> and L</pdl_sectors>. See also L</pdl_fill_sectors>,
L</pdl_ellipses>, and L</pdl_fill_ellipses>, as well as
L<Prima::Drawable/spline>.

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
lineEnds, linePatterns, lineWidths,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

################
# prima_clears #
################

@properties = qw(backColors rop2s translates);
pp_def('prima_clears',
	Pars => 'int x1(); int y1(); int x2(); int y2();'
			. generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['L'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('clears', \@properties, qw(x1 y1 x2 y2)),
	Code => 
	# I don't need any extra variables for clears, so I'll just add the
	# auto-generated declaration and initialization code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's clear function */
			my->clear(widget_handle, $x1(), $y1(), $x2(), $y2());
		%}
	])
	. generate_cleanup_code_for(@properties),
	Doc => q{

=head2 pdl_clears

  Prima Signature: (widget; x1(); y1(); x2(); y2(); properties)

=for ref

Clears the specified rectangle(s).

=for example

 my ($width, $height) = $canvas->size;
 # Begin by drawing a filled rectangle:
 $canvas->color(cl::Blue);
 $canvas->bar(0, 0, $width, $height);
 
 # Now cut random rectangles out of it:
 my $N_chunks = 20;
 my $x1 = random($N_chunks) * $width;
 my $x2 = random($N_chunks) * $width;
 my $y1 = random($N_chunks) * $width;
 my $y2 = random($N_chunks) * $width;
 $canvas->pdl_clears($x1, $y1, $x2, $y2);

Like the other examples, this will give you something new whenever you
resize the window if you put the code in the onPaint method, as the
Synopsis suggests.

Compare to the Prima method L<Prima::Drawable/clear>. In practice I
suppose this might be considered the opposite of L</pdl_bars>, though
technically this is meant for erasing, not drawing.

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, backColors, rop2s,
and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

####################
# prima_draw_texts #
####################

# Not implemented

##################
# prima_ellipses #
##################

@properties = qw(colors backColors clipRects linePatterns lineWidths rops rop2s translates);
pp_def('prima_ellipses',
	Pars => 'int x(); int y(); int x_diameter(); int y_diameter();'
			. generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['L'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('ellipses', \@properties, qw(x y x_diameter y_diameter)),
	Code => 
	# I don't need any extra variables for ellipses, so I'll just add the
	# auto-generated declaration and initialization code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's ellipse function */
			my->ellipse(widget_handle, $x(), $y(), $x_diameter(),
				$y_diameter());
		%}
	])
	. generate_cleanup_code_for(@properties),

	Doc => q{

=head2 pdl_ellipses

  Prima Signature: (widget; x(); y(); x_diameter();
                          y_diameter(); properties)

=for ref

Draws an ellipse centered at C<x>, C<y> with diameters C<x_diameter> and
C<y_diameter>. To draw circles, just use the same x- and y-diameter.

=for example

 working here

Compare to the Prima method L<Prima::Drawable/ellipse>. The filled
equivalent is L</pdl_fill_ellipses>. See also L</pdl_arcs>, L</pdl_chords>,
and L</pdl_sectors> as well as L</pdl_fill_chords> and
L</pdl_fill_sectors>. You may also be interested in L<Prima::Drawable/spline>,
which does not yet have a PDL interface.

=cut



}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
linePatterns, lineWidths,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

#####################
# prima_fill_chords #
#####################

@properties = qw(colors backColors clipRects fillPatterns rops rop2s translates);
pp_def('prima_fill_chords',
	Pars => 'int x(); int y(); int x_diameter(); int y_diameter();
			start_angle(); end_angle(); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['D'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('fill_chords', \@properties, qw(x y x_diameter y_diameter start_angle end_angle)),
	Code => 
	# I don't need any extra variables for chords, filled or otherwise,
	# so I'll just add the auto-generated declaration and initialization
	# code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's fill_chord function */
			my->fill_chord(widget_handle, $x(), $y(), $x_diameter(),
				$y_diameter(), $start_angle(), $end_angle());
		%}
	])
	. generate_cleanup_code_for(@properties),

	Doc => q{

=head2 pdl_fill_chords

  Prima Signature: (widget; x(); y(); x_diameter(); y_diameter();
                          start_angle(); end_angle(); properties)

=for ref

Draws an arc from C<start_angle> to C<end_angle> along the ellipse
centered at C<x>, C<y>, each with their specified diameters. The ends
are connected with a line and the interior is filled. Use this to draw
the open-mouth part of a smiley face.

=for example

 # working here:
 $canvas->pdl_fill_chords($x, $y, $xd, $yd, $ti, $tf);

Compare to the Prima method L<Prima::Drawable/fill_chord>. The unfilled
equivalent is L</pdl_chords>. Closely related to L</pdl_fill_ellipses>
and L</pdl_fill_sectors>. See also L</pdl_arcs>, L</pdl_ellipses>,
and L</pdl_sectors>.

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
fillPatterns,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

#######################
# prima_fill_ellipses #
#######################

@properties = qw(colors backColors clipRects fillPatterns rops rop2s translates);
pp_def('prima_fill_ellipses',
	Pars => 'int x(); int y(); int x_diameter(); int y_diameter();' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['L'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('fill_ellipses', \@properties, qw(x y x_diameter y_diameter)),
	Code => 
	# I don't need any extra variables for ellipses, filled or otherwise,
	# so I'll just add the auto-generated declaration and initialization
	# code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's fill_ellipse function */
			my->fill_ellipse(widget_handle, $x(), $y(), $x_diameter(), $y_diameter());
		%}
	])
	. generate_cleanup_code_for(@properties),

	Doc => q{

=head2 pdl_fill_ellipses

  Prima Signature: (widget; x(); y(); x_diameter();
                          y_diameter(); properties)

=for ref

Draws a filled ellipse centered at C<x>, C<y>, with diameters
C<x_diameter> and C<y_diameter>. To draw filled circles, use the same
value for both diameters.

=for example

 # working here
 $canvas->pdl_fill_ellipses($x, $y, $xd, $yd);

Compare to the Prima method L<Prima::Drawable/fill_ellipse>. The unfilled
equivalent is L</pdl_ellipses>. Closely related to L</pdl_fill_chords> and
L</pdl_fill_ellipses>, and L</pdl_fill_sectors>.
See also L</pdl_arcs>, L</pdl_ellipses>, and L</pdl_sectors>. Also,
check out L<Prima::Drawable/fill_spline>, which does not yet have
PDL bindings.

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
fillPatterns,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

####################
# prima_fillpolys #
####################

@properties = qw(colors backColors clipRects fillPatterns fillWindings rops rop2s translates);
my $code = 	# Begin by declaring the non-autogenerated the variables I will need
	q{
		DECLARE_POINT_DATA;
		int n_size, i, n_to_plot;
		double xval, yval;
	}
	# Add the auto-generated declaration and initialization code:
	. initialize_for(@properties)
	# Continue with my initialization code and the threadloop:
	. pp_line_numbers(__LINE__, q[
		/* Allocate an array of Points outside of the threadloop */
		n_size = $SIZE(n);
		INIT_POINT_DATA;
		
		/* All set. Start the threadloop with the setters. */
		threadloop %{
		])
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Put the x-y data into the to_plot array. I am attempting
			 * to handle infs gracefully, and I am simply skipping over
			 * nan values, treating them just as I would bad values.
			 * Note that polylines draws a gap at bad values, but here
			 * I simply skip over them.
			 */
			n_to_plot = 0;
			
			/* Ensure that we have the proper memory storage to communicate with
			 * this widget's fillpoly routine. */
			ENSURE_POINT_STORAGE (fillpoly, n_size);
			
			i = -1;
			while(1) {
				NEXT_I: i++;
				if (i >= n_size) break;
				
				xval = $x(n => i);
				yval = $y(n => i);

				/* Move to the next value if we encounter nan or BAD */
				if (xval != xval || yval != yval ORBADCHECKS) {
					goto NEXT_I;
				}

				/* This is a hack, but I'm leaving it like this for now because
				 * the full solution is very difficult */
				
				/* handle infinities */
				if (xval * 0.0 != 0.0) {
					if (xval < 0)
						xval = -MY_BIG_NUMBER;
					else
						xval = MY_BIG_NUMBER;
				}
				if (yval * 0.0 != 0.0) {
					if (yval < 0)
						yval = -MY_BIG_NUMBER;
					else
						yval = MY_BIG_NUMBER;
				}
				/* Handle very large values */
				if (yval > MY_BIG_NUMBER) yval = MY_BIG_NUMBER;
				if (xval > MY_BIG_NUMBER) xval = MY_BIG_NUMBER;
				if (yval < -MY_BIG_NUMBER) yval = -MY_BIG_NUMBER;
				if (xval < -MY_BIG_NUMBER) xval = -MY_BIG_NUMBER;
				
				ADD_POINT(fillpoly, n_to_plot, xval, yval);

				/* Keep track of the number of points added */
				n_to_plot++;
			}
			if (n_to_plot > 2)
				DRAW_POINTS(fillpoly, apc_gp_fill_poly, n_to_plot);
		%}
		
		/* Free the memory when done */
		FREE_POINT_STORAGE;
	])
	. generate_cleanup_code_for(@properties)
;

(my $good_code = $code) =~ s/ORBADCHECKS//;
(my $bad_code = $code) =~ s{ORBADCHECKS}{
					|| \$ISBAD(x(n => i))
					|| \$ISBAD(y(n => i))};
$bad_code =~ s/NEXT_I/NEXT_BAD_I/g;

pp_def('prima_fillpolys',
	Pars => 'x(n); y(n); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['D'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('fillpolys', \@properties, qw(x y)),
	Code => $good_code,
	BadCode => $bad_code,
	HandleBad => 1,
	Doc => q{

=head2 pdl_fillpolys

  Prima Signature: (widget; x(n); y(n); properties)

=for ref

Draws and fills a polygon with (mostly) arbitrary edge vertices.

NOTE: there is B<no> underscore between C<fill> and C<poly>, which is
different from the other C<fill> methods!

This is useful for drawing arbitrary filled shapes and for visualizing
integrals. Splines would be the better choice if you want to draw curves, but
a PDL interface to splines is not (yet) implemented.

Unlike most of the other methods, this one actually makes a half-hearted
effort to process bad values. In addition to the IEEE bad values of C<nan>
and C<inf>, PDL has support for bad values. Unlike in C<pdl_polys>,
C<pdl_fillpolys> will simply skip any point that is marked as bad, but drawing
the rest of the polygon. In other words, it reduces the degree of your polygon
by one. If you sent it four points and one of them was bad, you would get a
triangle instead of a quadralaters.

Infinities are also handled, though not perfectly. There are a few
situations where C<pdl_polys> will correctly draw what you mean but
C<pdl_fillpolys> will not.

Because this skips bad data altogether, if you have too much bad data
(i.e. fewer than three good points), the routine will simply not draw
anything. I'm debating if this should croak, or at least give a warning.
(Of course, a warning to STDOUT is rather silly for a GUI toolkit.)

For example:

=for example

 # working here
 $canvas->pdl_fillpolys($x, $y);

Compare to the Prima method L<Prima::Drawable/fillpoly>. See also
L</pdl_bars> and L<pdl_polylines>.

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
fillPatterns, fillWindings,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

######################
# prima_fill_sectors #
######################

@properties = qw(colors backColors clipRects fillPatterns rops rop2s translates);
pp_def('prima_fill_sectors',
	Pars => 'int x(); int y(); int x_diameter(); int y_diameter();
			start_angle(); end_angle(); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['D'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('fill_sectors', \@properties, qw(x y x_diameter y_diameter start_angle end_angle)),
	Code => 
	# I don't need any extra variables for filled sectors, so I'll just
	# add the auto-generated declaration and initialization code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's arc function */
			my->fill_sector(widget_handle, $x(), $y(), $x_diameter(),
				$y_diameter(), $start_angle(), $end_angle());
		%}
	])
	. generate_cleanup_code_for(@properties),

	Doc => q{

=head2 pdl_fill_sectors

  Prima Signature: (widget; x(); y(); x_diameter(); y_diameter();
                          start_angle(); end_angle(); properties)

=for ref

Draws an arc from C<start_angle> to C<end_angle> along the ellipse
centered at C<x>, C<y>, with specified x- and y-diameters. Like
L</fill_chords>, this command connects the end points of the arc, but
unlike L</fill_chords>, it does so by drawing two lines, both of which
also connect to the ellipse's center. This results in shapes that look
like pie pieces.

=for example

 # working here
 $canvas->pdl_fill_sectors($x, $y, $xd, $yd, $th1, $th2);

Compare to the Prima method L<Prima::Drawable/fill_sector>. The unfilled
equivalent is L</pdl_sectors>. This is closely related to C</pdl_fill_chords>
and C</pdl_fill_ellipses>. See also L</pdl_arcs>, L</pdl_chords>, and
L</pdl_ellipses>.

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
fillPatterns,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

######################
# prima_fill_splines #
######################

# Not implemented

#####################
# prima_flood_fills #
#####################

@properties = qw(colors backColors clipRects fillPatterns rops rop2s translates);
pp_def('prima_flood_fills',
	Pars => 'int x(); int y(); int color(); int singleborder(); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['L'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('flood_fills', \@properties, qw(x y color singleborder)),
	Code => 
	# I don't need any extra variables for flood fills, so I'll just add the
	# auto-generated declaration and initialization code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's flood fill function */
			my->flood_fill(widget_handle, $x(), $y(), (Color)$color(), $singleborder());
		%}
	])
	. generate_cleanup_code_for(@properties),

	Doc => q{

=head2 pdl_flood_fills

  Prima Signature: (widget; x(); y(); color();
                   singleborder(); properties)

=for ref

# working here:

Fills an area of the canvas...

=for example

 working here

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
fillPatterns,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

###############
# prima_lines #
###############

@properties = qw(colors backColors clipRects lineEnds lineJoins linePatterns lineWidths rops rop2s translates);
pp_def('prima_lines',
	Pars => 'x1(); y1(); x2(); y2(); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['D'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('lines', \@properties, qw(x1 y1 x2 y2)),
	Code => 
	# I'll need a couple of local variables to do my work here:
	q{
		Point * to_plot;
		big_number_container to_check;
	}
	# add the auto-generated declaration and initialization code:
	. initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties. It would be nice to skip bad values beforehand, but we
		# need the widget handle before we can check the points:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Assemble the big number checker */
			Point p = my->get_size(widget_handle);
			to_check.height = p.y;
			to_check.width = p.x;
			to_check.x1 = $x1();
			to_check.x2 = $x2();
			to_check.y1 = $y1();
			to_check.y2 = $y2();
			
			/* Call apricot's lines function if the line should be drawn */
			if (_check_for_big_numbers(&to_check) > 0) {
				my->line(widget_handle, to_check.x1, to_check.y1
					, to_check.x2, to_check.y2);
			}
		%}
	])
	. generate_cleanup_code_for(@properties),

	BadCode => 
	# I'll need a couple of local variables to do my work here:
	q{
		Point * to_plot;
		big_number_container to_check;
	}
	# add the auto-generated declaration and initialization code:
	. initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
			/* Skip any points that are bad */
			if ( $ISBAD(x1()) || $ISBAD(y1()) || $ISBAD(x2()) || $ISBAD(y2())) {
				continue;
			}
		]
		# Now comes the code that calls the various setters for the various
		# properties. It would be nice to skip bad values beforehand, but we
		# need the widget handle before we can check the points:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Assemble the big number checker */
			Point p = my->get_size(widget_handle);
			to_check.height = p.y;
			to_check.width = p.x;
			to_check.x1 = $x1();
			to_check.x2 = $x2();
			to_check.y1 = $y1();
			to_check.y2 = $y2();
			
			/* Call apricot's lines function if the line should be drawn */
			if (_check_for_big_numbers(&to_check) > 0) {
				my->line(widget_handle, to_check.x1, to_check.y1
					, to_check.x2, to_check.y2);
			}
		%}
	])
	. generate_cleanup_code_for(@properties),

	HandleBad => 1,
	Doc => q{

=head2 pdl_lines

  Prima Signature: (widget; x1(); y1(); x2(); y2(); properties)

=for ref

Draws a line from (x1, y1) to (x2, y2).

In contrast to polylines, which are supposed to be connected, these
lines are meant to be independent.

=for example

 working here

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
lineEnds, lineJoins, linePatterns, lineWidths,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

################
# prima_pixels #
################

#@properties = qw(colors clipRects translates);
#pp_def('prima_pixels',
#	Pars => 'int x(); int y(); int [o] color(); ' . generate_pars_args_for(@properties),
#	OtherPars => $default_other_pars,
#	GenericTypes => ['L'],
#	PMFunc => undef,
#	NoPthread => 1,
#	PMCode => generate_PMCode_for('pixels', \@properties, qw(x y color)),
#	Code => 
#	# I don't need any extra variables for pixels, so I'll just add the
#	# auto-generated declaration and initialization code:
#	  initialize_for(@properties)
#	# Continue with the threadloop:
#	. pp_line_numbers(__LINE__, q{
#		threadloop %{
#			/* Unlike usual, I will not use the setter code. Rather,
#			 * the is_setting_colors will determine whether or not I
#			 * set the pixel:
#			 *
#			 * working here: no initialize_for(@properties)?
#			 */
#			if (is_setting_colors) {
#				my->set_pixel(widget_handle, $x(), $y(), (Color)$colors());
#			}
#			
#			/* No matter what, get the previous color. NOTE that the
#			 * retrieved results goes in color (singular), not colors
#			 */
#			$color() = (PDL_Long) my->get_pixel(widget_handle, $x(), $y());
#		%}
#	}),
#	BadCode =>
#	# I don't need any extra variables for pixels, so I'll just add the
#	# auto-generated declaration and initialization code:
#	  initialize_for(@properties)
#	# Continue with the threadloop:
#	. pp_line_numbers(__LINE__, q{
#		threadloop %{
#			/* Unlike usual, I will not use the setter code. Rather,
#			 * the is_setting_colors, and the good state for everything, is
#			 * will determine whether or not I set the pixel:
#			 */
#			if (is_setting_colors && $ISGOOD(x()) && $ISGOOD(y())
#					&& $ISGOOD(colors())) {
#				my->set_pixel(widget_handle, $x(), $y(), (Color)$colors());
#			}
#			
#			/* No matter what, get the previous color. NOTE that the
#			 * retrieved results goes in color (singular), not colors
#			 */
#			$color() = (PDL_Long) my->get_pixel(widget_handle, $x(), $y());
#		%}
#	}),
#	HandleBad => 1,
#	Doc => q{
#
#=head2 pdl_pixels
#
#  Prima Signature: (widget; x(); y(); properties)
#
#=for ref
#
#Sets the pixel at (x, y) to the current color, or to the value(s) passed
#in the C<color> property.
#
#=for example
#
# working here
#
#=cut
#
#}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
#\n=cut
#
#");
#
#=pod
#
#Applicable properties are likely to include handles, colors, clipRects, and
#translates. However, this list could be
#out of date or out of order. If you've installed this module on your own
#machine, the documentation is guaranteed to describe the applicable
#properties, in their correct order.
#
#=cut

###################
# prima_polylines #
###################

@properties = qw(colors backColors clipRects lineEnds lineJoins linePatterns
					lineWidths rops rop2s translates);
$code = 	# Begin by declaring the non-autogenerated variables I will need
	q{
		DECLARE_POINT_DATA;
		int n_size, i, n_to_plot;
		int width, height, check_result;
		big_number_container to_check;
	}
	# Add the auto-generated declaration and initialization code:
	. initialize_for(@properties)
	# Continue with my initialization code and the threadloop:
	. pp_line_numbers(__LINE__, q[
		/* Allocate the point data outside of the threadloop */
		n_size = $SIZE(n);
		INIT_POINT_DATA;
		
		/* All set. Start the threadloop with the setters. */
		threadloop %{
		])
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Make sure that we have the proper point storage for this widget */
			ENSURE_POINT_STORAGE(polyline, n_size);
			
			/* Get the width and height of the widget */
			Point p = my->get_size(widget_handle);
			to_check.height = p.y;
			to_check.width = p.x;
			
			i = 0;
			NEXT_I: while(i < n_size - 1) {
				to_check.x1 = $x(n => i);
				to_check.y1 = $y(n => i);
				i++;
				CHECK_FOR_BAD;
				/* Add the first point to the collection */
				ADD_POINT(polyline, 0, to_check.x1, to_check.y1);
				
				for(n_to_plot = 1; i < n_size; i++, n_to_plot++) {
					to_check.x2 = $x(n => i);
					to_check.y2 = $y(n => i);
					
					check_result = IS_BAD ? 0 : _check_for_big_numbers(&to_check);
					
					if (check_result == 0) {
						/* That means "don't plot this segment", which means
						 * I should plot the other pieces and start over with
						 * a new sub-segment. */
						if (n_to_plot > 1)
							DRAW_POINTS(polyline, apc_gp_draw_poly, n_to_plot);
						
						goto NEXT_I;
					}
					if (check_result > 1) {
						/* That means "I had to adjust x and y", which means
						 * I should plot the current sub-segment and start a
						 * new sub-segment. */
						if (n_to_plot == 1) {
							/* re-add the zeroeth point since it might have
							 * been changed. Note that all later points will
							 * only trigger this if they are exotic, but the
							 * n==1 could trigger this if the zeroeth point is
							 * exotic */
							ADD_POINT(polyline, 0, to_check.x1, to_check.y1);
						}
						
						ADD_POINT(polyline, n_to_plot, to_check.x2, to_check.y2);
						DRAW_POINTS(polyline, apc_gp_draw_poly, n_to_plot+1);
						goto NEXT_I;
					}
					
					ADD_POINT(polyline, n_to_plot, to_check.x2, to_check.y2);
					
					to_check.x1 = to_check.x2;
					to_check.y1 = to_check.y2;
				}
				
				/* The only way we reach here is if the last segment was fine,
				 * but was not drawn, so draw it. */
				DRAW_POINTS(polyline, apc_gp_draw_poly, n_to_plot);
			}
		%}
		
		/* Free the memory when done */
		FREE_POINT_STORAGE;
	])
	. generate_cleanup_code_for(@properties)
	;

($good_code = $code) =~ s/CHECK_FOR_BAD//;
$good_code =~ s/IS_BAD/0/;
($bad_code = $code) =~ s{CHECK_FOR_BAD}{if (\$ISBAD(x(n => i-1)) || \$ISBAD(y(n => i-1))) goto NEXT_I};
$bad_code =~ s{IS_BAD}{(\$ISBAD(x(n => i)) || \$ISBAD(y(n => i)))};
$bad_code =~ s/NEXT_I/NEXT_BAD_I/g;


pp_def('prima_polylines',
	Pars => 'x(n); y(n); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['D'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('polylines', \@properties, qw(x y)),
	Code => $good_code,
	HandleBad => 1,
	BadCode => $bad_code,

	Doc => q{

=head2 pdl_polylines

  Prima Signature: (widget; x(n); y(n); properties)

=for ref

Draws a multi-segment line on a widget with the given x- and y-coordinates.

This is useful for making line-drawings, such as plotting data.

=for example

 # Draw a sine curve on the widget:
 my $x = sequence(200);
 my $y = ( sin($x / 20) + 1 ) * 50;
 $canvas->pdl_polylines($x, $y);

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
lineEnds, lineJoins, linePatterns, lineWidths,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.
				color, backColor, linePattern, lineWidth, lineJoin, lineEnd, rop, rop2

=cut

####################
# prima_put_images #
####################

# Not implemented

#############################
# prima_put_images_indirect #
#############################

# Not implemented

#################
# prima_rects3d #
#################

# Not implemented

###################
# prima_rect_foci #
###################

# Not implemented

####################
# prima_rectangles #
####################

@properties = qw(colors backColors clipRects linePatterns lineWidths rops rop2s translates);
pp_def('prima_rectangles',
	Pars => 'int x1(); int y1(); int x2(); int y2(); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['L'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('rectangles', \@properties, qw(x1 y1 x2 y2)),
	Code => 
	# I don't need any extra variables for bars, so I'll just add the
	# auto-generated declaration and initialization code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's rectangle function */
			my->rectangle(widget_handle, $x1(), $y1(), $x2(), $y2());
		%}
	])
	. generate_cleanup_code_for(@properties),

	Doc => q{

=head2 pdl_rectangles

  Prima Signature: (widget; x1(); y1(); x2(); y2(); properties)

=for ref

Draws a rectangle from corner (x1, y1) to (x2, y2).

=for example

 working here

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
linePatterns, lineWidths,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

#################
# prima_sectors #
#################

@properties = qw(colors backColors clipRects lineEnds linePatterns lineWidths rops rop2s translates);
pp_def('prima_sectors',
	Pars => 'int x(); int y(); int x_diameter(); int y_diameter();
			start_angle(); end_angle(); ' . generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['D'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('sectors', \@properties, qw(x y x_diameter y_diameter start_angle end_angle)),
	Code => 
	# I don't need any extra variables for sectors, so I'll just add the
	# auto-generated declaration and initialization code:
	  initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Call apricot's arc function */
			my->sector(widget_handle, $x(), $y(), $x_diameter(),
				$y_diameter(), $start_angle(), $end_angle());
		%}
	])
	. generate_cleanup_code_for(@properties),

	Doc => q{

=head2 pdl_sectors

  Prima Signature: (widget; x(); y(); x_diameter(); y_diameter(); start_angle(); end_angle(); properties)

=for ref

Draws an arc from C<start_angle> to C<end_angle> along the ellipse
centered at C<x>, C<y>, each with their specified diameters. The
difference between this command and L<chords> is that this command does
not connect the ends of the arcs with straight lines but leaves the
arcs open

=for example

 working here

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include handles, colors, backColors, clipRects,
lineEnds, linePatterns, lineWidths,
rops, rop2s, and translates. However, this list could be
out of date or out of order. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable
properties, in their correct order.

=cut

#################
# prima_splines #
#################

# Not implemented

########################
# prima_stretch_images #
########################

# Not implemented

###################
# prima_texts_out #
###################

# Not implemented


##########################################
# Additional PDL-only drawing operations #
##########################################

pp_addpm(<<ModuleMaterial);

=head2 PDL-ONLY METHODS

These are drawing methods that have no analogous Prima::Drawable function.

=cut

ModuleMaterial

#################
# prima_symbols #
#################

# The code and badcode are nearly identical, so I'll write it once here and
# do the handful of manipulations below.

@properties = qw(colors backColors clipRects fillPatterns lineEnds
				linePatterns lineWidths rops rop2s translates);
	# I'll need to allocate the memory for each Symbol drawn:
$code = 	q{
		DECLARE_POINT_DATA;
		int i, j, N_sides, N_steps, reduced_skip;
		double angle;
		double TWOPI = 8.0 * atan2(1,1);
		
	}
	# add the auto-generated declaration and initialization code:
	. initialize_for(@properties)
	# Continue with the threadloop:
	. q[
		INIT_POINT_DATA;
		threadloop %{
		]
		# Now comes the code that calls the various setters for the various
		# properties:
		. generate_setter_code_for(@properties)
		. pp_line_numbers(__LINE__, q[
			/* Figure out the reduced_skip */
			if ($N_points() > 2) reduced_skip = $skip() % $N_points();
			
			/* Skip bad values */
			if(is_nan($x()) || is_nan($y()) || is_inf($x()) || is_inf($y())
				BADCHECKS) {
				/* do nothing */
			}
			else if ($N_points() == 0 || $N_points() == 1) {
				/* Handle the circle case up-front */
				if ($filled() == 0) {
					my->ellipse(widget_handle, $x(), $y(), 2*$size(), 2*$size());
				}
				else {
					my->fill_ellipse(widget_handle, $x(), $y(), 2*$size(), 2*$size());
				}
			}
			else if (reduced_skip == 0
				/* Handle the zero-skip case next, which draws lines from the
				 * center to each point */
					|| $N_points() % 2 == 0 && reduced_skip == $N_points() / 2) {
				angle = TWOPI * $orientation() / 360.0;
				N_sides = $N_points();
				for(i = 0; i < N_sides; ++i) {
					/* draw lines from the center to each point */
					my->line(widget_handle, $x(), $y()
						, $x() + $size() * cos(angle)
						, $y() + $size() * sin(angle));
					/* update the angle */
					angle += TWOPI / N_sides;
				}
			}
			else {
				/* Look for the least common divisor of reduced_skip and N_points */
				N_steps = 1;
				for (i = 2; i <= reduced_skip; ++i)
					if (reduced_skip % i == 0 && $N_points() % i == 0)
						N_steps = i;
				/* Figure out the number of sides we'll be plotting at any
				 * given moment */
				N_sides = $N_points() / N_steps + 1;
				
				/* Allocate the memory needed for the Symbol */
				if ($filled() == 0) ENSURE_POINT_STORAGE(polyline, N_sides);
				else ENSURE_POINT_STORAGE(fillpoly, N_sides);
				
				for (j = 0; j < N_steps; j++) {
					angle = TWOPI * ($orientation() / 360.0 + (double)j / $N_points());
					/* Calculate the points for the Symbol */
					for (i = 0; i < N_sides; ++i) {
						ADD_POINT(polyline, i
							, $x() + $size() * cos(angle)
							, $y() + $size() * sin(angle));
						angle += TWOPI/$N_points() * reduced_skip;
					}
					
					if ($filled() == 0) {
						/* Draw a non-filled polygon */
						DRAW_POINTS(polyline, apc_gp_draw_poly, N_sides);
					}
					else {
						/* Draw a filled-in polygon */
						DRAW_POINTS(fillpoly, apc_gp_fill_poly, N_sides);
					}
				}
				
				/* Free the memory when done */
				FREE_POINT_STORAGE;
			}
		%}
	])
	. generate_cleanup_code_for(@properties);

($good_code = $code) =~ s/BADCHECKS//;
my $bad_checks = '|| $ISBAD(x()) || $ISBAD(y()) || $ISBAD(N_points())
					|| $ISBAD(orientation()) || $ISBAD(filled())
					|| $ISBAD(size()) || $ISBAD(skip())';
($bad_code = $code) =~ s/BADCHECKS/$bad_checks/;

pp_def('prima_symbols',
	Pars => 'x(); y(); byte N_points(); orientation(); byte filled(); int size(); byte skip(); '
				. generate_pars_args_for(@properties),
	OtherPars => $default_other_pars,
	GenericTypes => ['D'],
	PMFunc => undef,
	NoPthread => 1,
	PMCode => generate_PMCode_for('symbols', \@properties, qw(x y N_points orientation filled size skip)),
	Code => $good_code,
	HandleBad => 1,
	BadCode => $bad_code,
	Doc => q{

=head2 pdl_symbols

  Signature: (widget; x(); y(); N_points(); orientation(); filled(); size(); skip(); properties)

=for ref

Draws a wide variety of symbols centered at (x, y).

Through various combinations of C<N_points>, C<filled>, and C<skip>, you can
generate many different regular symbols, including dashes, stars, asterisks,
triangles, and diamonds. You can also specify each symbol's C<size> and
C<orientation>. The size is the radius of a circle that would circumscribe
the shape. The orientation is... well... just keep reading.

The shape drawn depends on C<N_points>. If C<N_points> is:

=over

=item zero or one

This will draw a circle with a radius of the
given size. The circle will be filled or not based on the value passed for
C<filled>, but the C<orientation> and C<skip> parameters are ignored. This
is almost redundant compared with the ellipse functions, except that this
arrangement makes it very easy to thead over filled/not-filled, and you
cannot specify an eccentricity for your points using C<pdl_symbols>.

=item two

This will draw a line centered at (x, y) and with a length of 2*C<size>.
The C<orientation> is measured in degrees, starting from horizontal, with
increasing angles rotating the line counter-clockwise. The value for C<skip>
is ignored.

This is particulary useful for visualizing slope-fields (although calculating
the angles for the slope field is surprisingly tricky).

=item three or more

This will draw a shape related to a regular polygon with the specified
number of sides. Precisely what kind of polygon it draws is based on the
value of C<skip>. For example, a five-sided polygon with a C<skip> of one
would give you a pentagon:


                           second point
                               _
               third   __..--'' \
               point  |          \
                      |           \
                      |            \  first
                      |            /  point
                      |           /
                      |__        /
              fourth     ``--.._/
              point
                           fifth point

                           skip = 1

In contrast, a five-sided polygon with a skip of 2 will give you a star:

                           fourth point
                           
              second          /|                
              point   \`~.._/  |            
                       `\ / `--|.__          
                         X     | __>  first point       
                       ,/ \_,--|'                
              fifth   /_~'' \  |                 
              point           \|
                            
                           third point
 
                           skip = 2

A skip of three would give visually identical results but the actual order
in which the vertices are drawn is different:

                           third point
                           
              fifth           /|                
              point   \`~.._/  |            
                       `\ / `--|.__          
                         X     | __>  first point       
                       ,/ \_,--|'                
              second  /_~'' \  |                 
              point           \|
                            
                           fourth point
 
                           skip = 3

A skip of zero is a special case, and means I<draw lines to each point from
the center.> In other words, create an asterisk:

                           second point
                               
               third            /
               point   `.      / 
                         `.   /   
                           `./_______  first
                           .'\         point
                         .'   \
                       .'      \
              fourth            \
              point
                           fifth point
 
                           skip = 0

In summary, a C<skip> of zero gives you an N-asterisk. A C<skip> of one gives
you a regular polygon. A C<skip> of two gives you a star. And so forth.
Higher values of C<skip> are allowed; they simply add to the winding behavior.

Specifying the orientation changes the position of the first point and,
therefore, all subsequent points. A positive orientation rotates the first
point counter-clockwise by the specified number of degrees. Obviously, due
to the symmetry of the shapes, rotations of 360 / N_points look identical to
not performing any rotation.

For all nonzero values of C<skip>, specifying a fill will end up with
a filled shape instead of a line drawing.

=back

By default, filled stars and other symbols with odd numbers of points have a
hole in their middle. However, Prima provides a means for indicating that you
want such shapes filled; that is the C<fillWinding> property. As with almost all
graphical properties, you can specify the C<fillWinding> property for each
symbol by specifying the C<fillWindings> piddle.

This example creates a table of shapes. It uses an argument from the command
line to determine the line width.

=for example

 use PDL::NiceSlice;
 
 # Generate a table of shapes:
 my @dims = (40, 1, 30);
 my $N_points = xvals(@dims)->clump(2) + 1;
 my $orientation = 0;
 my $filled = yvals(@dims)->clump(2) + 1;
 my $size = 10;
 my $skip = zvals(@dims)->clump(2);
 my $x = $N_points->xvals * 25 + 25;
 my $y = $N_points->yvals * 25 + 25;
 my $lineWidths = $ARGV[0] || 1;
 
 # Draw them:
 $canvas->pdl_symbols($x, $y, $N_points, 0, $filled, 10, $skip

=for bad

Bad values are handled by C<pdl_symbols>. If any of the values you pass in
are bad, the symbol is not drawn at that x/y coordinate.

=cut

}. "=pod\n\nApplicable properties include " . join(', ', 'handles', @properties) . "
\n=cut

");

=pod

Applicable properties are likely to include colors, backColors, clipRects,
fillPatterns, lineEnds, linePatterns, lineWidths, rops, rop2s, and translates.
However, this list could be out of date. If you've installed this module on your own
machine, the documentation is guaranteed to describe the applicable properties.

=cut


pp_addpm({At=>'Bot'},<<'EOD');

=head1 ERROR MESSAGE

These functions may throw the following exception:

=head2 Your widget must be derived from Prima::Drawable

This means that you tried to draw on something that is not a Prima::Drawable
object, or a class derived from it. I don't know enough about the Prima
internals to know if that has any hope of working, but why do it in the first
place?

=head1 PDL::PP DETAILS

Those well versed in PDL::PP might ask how I manage to produce pdlified methods
that take variable numbers of arguments. That is a long story, and it is told in
the volumes of comments in pdlprima.pd. Give it a read if you want to know what
goes on behind the scenes.

=head1 TODO

These are all the things I wish to do:

=over

=item Full Drawabel API

I would like a PDL function for every drawable function in the API.
Prima Drawable functions that currently do not have an equivalent PDL
implementation include L<Prima::Drawable/draw_text>,
L<Prima::Drawable/fill_spline>, L<Prima::Drawable/put_image>,
L<Prima::Drawable/put_image_indirect>, L<Prima::Drawable/rect3d>,
L<Prima::Drawable/rect_focus>, L<Prima::Drawable/spline>,
L<Prima::Drawable/stretch_image>, and L<Prima::Drawable/text_out>

=item Bad Value Support

Bad values are handled decently in L</polylines> and L</fillpolys>, but not for
the other functions. Bad x/y values should be skipped for almost all the drawing
primitives, but what about bad colors for valid coordinates? I could not draw
the primitive, defer to the widget's default color, or use the value associated
with the singular key (i.e. C<color>). But I haven't decided which of these is
best.

=item "Atomic" Operations

I would like to be able to specify colors, for example, and have the state of
the widget revert back to the original color after the drawing command has
finished. In other words, I would like the state of the widget after these
drawing commands to be the same that it was before these commands. This can be
implemented by having the drawing commands backup the widget's properties before
running, and restoring them afterwards.

=back

=head1 AUTHOR

David Mertens, E<lt>dcmertens.perl@gmail.comE<gt>.

=head1 SEE ALSO

Some useful PDL/Prima functions are defined in L<PDL::Drawing::Prima::Utils>,
especially for converting among simple color formats.

This is built as an extension for the Prima toolkit, http://www.prima.eu.org/, L<Prima>.

This is built using (and targeted at users of) the Perl Data Language, L<PDL>.

This is the bedrock for the plotting package L<PDL::Graphics::Prima>.

Another interface between PDL and Prima is <PDL::PrimaImage>. I am indebted to
Dmitry for that module because it gave me a working template for this module,
including a working Makefile.PL. Thanks Dmitry!

=cut

EOD


pp_export_nothing();
pp_done();

#__END__

#############################
# Remove incorrect PDL docs #
#############################
# removes the stupid full-signature documentation.
# working here - this can be removed by properly handling the Doc key in the
# pp_def function call. When you supply an empty string, no documentation gets
# generated. That lets me to add my own pod in the PMCode section.

# However, I'm also going to add a 'use Prima' at the top for Windows machines,
# so I'm going to keep this section, even if I reduce the pod-parsing portion. 

my $base = "$base_name.pm";
my $new = "$base_name-new.pm";

open my $in, '<', $base;
open my $out, '>', $new;

# Add 'use Prima' to the top so that symbol lookups work correctly.
print $out <<'ALWAYS_LOAD';
# Always load Prima first:
use Prima;

ALWAYS_LOAD

my $is_discarding = 0;
my $found_functions = 0;

LINE: while (<$in>) {
	if ($is_discarding) {
		# Discard the line unless we find our end marker:
		next LINE unless /=head2 pdl_/;
		$is_discarding = 0;
	}
	elsif (/=head2 prima_/) {
		# Check if we *should* start discarding:
		$is_discarding = 1;
		next LINE;
	}
	
	# Remove the spurious =head1 FUNCTIONS documentation
	if ($found_functions and /=head1 FUNCTIONS/) {
		# Eat everything up to the =cut
		while(<$in> !~ /=cut/) {}
		next LINE;
	}
	$found_functions++ if /=head1 FUNCTIONS/;
	
	s/(?<!_)prima_/pdl_/;
	
	print $out $_;
}

close $in;
close $out;
unlink $base;
rename $new => $base;


