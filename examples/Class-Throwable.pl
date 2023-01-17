use v5.36;
my @a=qw<a,b,c>;
use Class::Throwable;# VERBOSE=>1;
Class::Throwable->setVerbosity(2);
#use Exception::Class;
use Error::Show;
use feature "try";
sub my_func {
  try{
    Class::Throwable->throw("Something has gone wrong");

  }
  catch($e){
    use Data::Dumper;
    say  $e->stackTraceToString;
    my @lines=split "\n", $e->stackTraceToString;
    for(@lines){
      my ($file, $line)=/called in (.*?) line (\d+) ]/;
      say $file, $line;
    }
    say $e;
    exit;

    say Dumper $e->getStackTrace;
    say "CONTEXT:";
    say Error::Show::context $e;
    say "";
    say "Tracer";
    say $e;
    use Data::Dumper;
    say $e->getStackTrace;
  }
}

sub my_func2{
  my_func;
}
warn "some warning";
my_func2;
