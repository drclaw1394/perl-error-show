use Exception::Base;
#use Exception::Class;
use Error::Show;
use v5.36;
use feature "try";
sub my_func {
  try{
    Exception::Base->throw("An error occured");
  }
  catch($e){
    $e->verbosity(4);
    say Error::Show::trace_context $e;
    say "$e";
    say join "\n", $e->get_caller_stacktrace;
  }
}

sub my_func2{
  my_func;
}

my_func2;
