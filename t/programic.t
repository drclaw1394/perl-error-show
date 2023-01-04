use strict;
use warnings;
use feature ":all";

use Test::More tests => 1;
BEGIN { use_ok('Error::Show') };

use Error::Show;

my $program=
q|#THIS IS  
#evaled code
#which throws an error here  \/	
print "asdfasd';
#hese comments are after the error
#as are these


|;


{
	#basic eval
	my $result;
	
	$result =eval $program;
	say STDERR Error::Show::context indent=>"xxxx", program=>\$program, error=>$@;
	
	$result=eval {1/0;};
	say STDERR Error::Show::tracer indent=>"yyyy", error=>$@;#, __FILE__;
}
exit;
use File::Basename qw<dirname>;

my $dirname=dirname __FILE__;
my $path=$dirname."/require.t.pl";

#say STDERR "Testing require: ";
#eval {require $path} or  $@ and say STDERR Error::Show::context $path, $@ ;

#say STDERR "Testing do: ";

#do $path or  $@ and say STDERR Error::Show::context $path, $@ ;

say STDERR "Testing require try catch";
eval {
	require $path;
};
if($@){
	#say STDERR"try catch error $e";
	say STDERR Error::Show::context indent=>"xxxx", error=>$@, $path
}
