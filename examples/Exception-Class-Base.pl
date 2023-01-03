use Exception::Class;
use Error::Show;
use v5.36;
use feature "try";
sub my_func {
  try{
    Exception::Class::Base->throw("An error occured");
  }
  catch($e){
    say Error::Show::tracer $e;
    #say Error::Show::tracer trace=>$e->trace;
    #say "$e";
    #say ref $e->trace;
  }
}

sub my_func2{
  my_func;
}

my_func2;
