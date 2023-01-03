use v5.36;
use strict;
use warnings;
use feature "try";

use Test::More tests=>1;

use Error::ShowMe;
use Carp qw<verbose croak>;


{
	sub level2 {
		#Error::ShowMe::dump_trace 
		croak [];#"asdf";
	}

	sub level1 {
		level2;
	}

	my $ret;
	local $SIG{__DIE__}=sub { say STDERR "HOOK", $_[0]};
	try {
		$ret=level1;

	}
	catch($e){
		say "CAUGHT ERROR", $e;
		#say STDERR Error::ShowMe::context _;

	}
	ok !defined $ret;
}

{
		my $ret=eval q|my $a=1;

		say STDERR "want array in eval: ".wantarray;
		$a/0;
		|;
		$ret;
}
