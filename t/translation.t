use strict;
use warnings;

use feature "say";
use Test::More tests=>1;

use Error::Show;
use Carp qw<verbose croak>;


{
	sub level2 {
		croak [];#"asdf";
	}

	sub level1 {
		level2;
	}

	my $ret;
	local $SIG{__DIE__}=sub { say STDERR "HOOK", $_[0]};
	eval {
		$ret=level1;

	};
	if($@){
		say STDERR "CAUGHT ERROR", $@;

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
