use Exception::Base verbosity=>4;
#use Exception::Class;
use Error::Show;
use v5.36;
use feature "try";
sub my_func {
  try{
    my $e= Exception::Base->new();
    $e->verbosity(10);
    $e->throw();

  }
  catch($e){
    say "CONTEXT:";
    say Error::Show::context $e;
    say "";
    say "Tracer";
    use Data::Dumper;
    #say Dumper $e->get_caller_stacktrace;
    say Dumper $e->caller_stack;
  }
}

sub my_func2{
  my_func;
}

my_func2;
