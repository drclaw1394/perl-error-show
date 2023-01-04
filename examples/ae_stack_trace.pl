use v5.36;
use strict;
use warnings;
use feature "try";
no warnings "experimental";

use Exception::Class::Base;
use AnyEvent;
use Error::Show;
my $cv=AE::cv;
my $timer; $timer=AE::timer 0,0, sub {
  try{
      die "I died";
  }
  catch($e){
    print STDERR Error::Show::tracer pre_lines=>10, post_lines=>10, error=>$e;
  }



  try{
      Exception::Class::Base->throw("murdered");
  }
  catch($e){
    use Data::Dumper;
    #print Dumper $e->trace;;
    print STDERR Error::Show::tracer clean=>1,error=>$e;# pre_lines=>10, post_lines=>10, error=>$e;
  }

  try{
      Exception::Class::Base->throw("murdered again");
  }
  catch($e){
    use Data::Dumper;
    #print Dumper $e->trace;;
    print STDERR Error::Show::tracer error=>$e;# pre_lines=>10, post_lines=>10, error=>$e;
  }

	$timer=undef;
	$cv->send;
};



$cv->recv;
