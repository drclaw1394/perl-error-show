use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('Error::ShowMe') };

use Error::ShowMe ();

my $program=
q|#THIS IS  
#evaled code
#which throws an error here  \/	
print "asdfasd';
#hese comments are after the error
#as are these


|;

my $result=eval $program;

print STDERR Error::ShowMe::context(\$program, $@);
print STDERR "\n";

use File::Basename qw<dirname>;

my $dirname=dirname __FILE__;
my $path=$dirname."/require.t.pl";

use feature ":all";

say STDERR "Testing require: ";
#eval {require $path} or  $@ and say STDERR Error::ShowMe::context $path, $@ ;

say STDERR "Testing do: ";

#do $path or  $@ and say STDERR Error::ShowMe::context $path, $@ ;

say STDERR "Testing require try catch";
try {
	require $path;
}
catch ($e){
	#say STDERR"try catch error $e";
	say STDERR Error::ShowMe::context $path, $e ;
}
