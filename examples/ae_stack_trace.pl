use warnings;
use strict;
use AnyEvent;
use Error::Show;
my $cv=AE::cv;
my $timer; $timer=AE::timer 0,0, sub {
  print STDERR Error::Show::trace_context pre_lines=>10, post_lines=>10;
	$timer=undef;
	$cv->send;
};
$cv->recv;
