use Exception::Class;
use Error::Show;
use v5.36;
use feature "try";
sub my_func {
  try{
    Exception::Class::Base->throw("An error occured");
  }
  catch($e){

    say "CONTEXT: ".$e->line, $e->file, "$e";
    say Error::Show::context $e;#{line=>$e->line, file=>$e->file, message=>"$e"};

    say Error::Show::context {line=>$e->line, file=>$e->file, message=>"$e"};


    my @temp=map {{file=>$_->filename, line=>$_->line, message=>$e}} $e->trace->frames;
    say Error::Show::context \@temp;

    say "";
    say "Tracer";
  }


  my $string='"Hello
    and something eler
   to look at"';
  eval  $string;
  if($@){
    say Error::Show::context program=>$string, error=>$@;
  }
}

sub my_func2{
  my_func;
}

my_func2;
