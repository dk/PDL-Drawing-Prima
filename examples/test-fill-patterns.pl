 use strict;
 use warnings;
 use PDL;
 # Windows dynamic loading requires that Prima comes before PDL::Drawing::Prima
 use Prima qw(Application);
 use PDL::Drawing::Prima;
 
 my $fillPattern = pdl(
    0b00000000,
    0b01111110,
    0b01000010,
    0b01011010,
    0b01011010,
    0b01000010,
    0b01111110,
    0b00000000,
 );
 
 my $window = Prima::MainWindow->create(
     text    => 'PDL::Graphics::Prima Test',
     fillPattern => fp::Interleave,
     onPaint => sub {
         my ( $self, $canvas) = @_;
 
         # wipe and replot:
         $canvas->clear;
         
         ### Example code goes here ###

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
         , colors => $colors
         , fillPattern => fp::Line
#         , fillPatterns => $fillPattern
         );
         
         $canvas->bar(0, 0, 30, 30);
         
     },
     backColor => cl::White,
 );
 
 run Prima;
