use AnyEvent;
use Error::ShowMe;

my $cv=AE::cv;
my $timer; $timer=AE::timer 0,0, sub {
	print STDERR Error::ShowMe::trace_context pre_lines=>10, post_lines=>10;
	$timer=undef;
	$cv->send;
};
$cv->recv;
