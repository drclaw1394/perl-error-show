package Error::Show;

use 5.024000;
use strict;
use warnings;
use feature "say";



our $VERSION = 'v0.4.0';

use constant::more DEBUG=>undef;
use constant::more {
  PACKAGE=>     0,
  FILENAME=>    1,
  LINE=>        2,
  SUBROUTINE=>  3,
  HASARGS=>     4,
  WANTARRAY=>   5,
  EVALTEXT=>    6,
  IS_REQUIRE=>  7,
  HINTS=>       8,
  BITMASK=>     9,
  HINT_HASH=>   10,
  MESSAGE=>     11,
  SEQUENCE=>    12,
  CODE_LINES=>  13,
};

#
# A list of top level file paths or scalar refs to check for syntax errors
#
my @IINC;
sub context;

my %programs;
 
sub import {
  my $package=shift;
  # Add support for reexporters that manipulate the export level
  my @caller=caller($Exporter::ExportLevel//0);;
  my @options=@_;


  # Only have one sub to export and we only export it if the caller has a line
  # number. Otherise we are being invoked from the CLI
  #
  if($caller[LINE]){
    no strict "refs";
    my $name=$caller[0]."::context";
    *{$name}=\&{"context"};
    return; 
  }

  # 
  # CLI Options include 
  #

  require POSIX;  #For _exit;
  require IPC::Open3;
  require Symbol;
  my %options;

  my $clean=grep /clean/i, @options;
  my $splain=grep /splain/i, @options;
  my $do_warn=grep /warn/i, @options;
  my $no_handler=grep /no_handler/i, @options;

  my @warn=$do_warn?():"-MError::Show::Internal";


  #
  # 1. Command line argument activation ie -MError::Show
  #
  # Find out any extra lib paths used. To do this we:
  #
  # a. fork/exec a new perl process using the value of $^X. 
  # b. The new process dumps the @INC array to STDOUT
  # c. This process reads the output and stores in @IINC
  #
  # Only run it the first time its used
  # Is this the best way? Not sure. At least this way there is no argument
  # processing, perl process does it for us.
  #
  
  @IINC=map {chomp; $_} do {
    open my $fh, "-|", $^X . q| -E 'map print("$_\n"), @INC'| or die "$!";
    <$fh>;
  } unless @IINC;

  #
  # 2. Extract the extra include paths
  #
  # Built up the 'extra' array of any include paths not already listed 
  # from the STDOUT dumping above
  #
  my @extra=map  {("-I", $_)} grep {my $i=$_; !grep { $i eq $_} @IINC} @INC;



  # 
  # 3. Syntax checking the program
  #
  # Now we have the include paths sorted,
  # a. fork/exec again, this time with the -c switch for perl to check syntax
  # b. slurp STDERR from child process
  # c. execute the context routine to parse and show more source code context
  # d. print!
  # The proc

  local $/=undef;
  my $file=$0;

  #push @file, @ARGV;

  #my $runnable=not $^C;#$options{check};
  #for my $file(@file){
  die "Error::Show cannot process STDIN, -e and -E programs" if $file eq "-e" or $file eq "-E" or $file eq "-";
  die "Error::Show cannot access \"$file\"" unless -f $file;
  my @cmd= ($^X ,@warn, @extra, "-c",  $file);

    my $pid;
    my $result;
    eval {
      $pid=IPC::Open3::open3(my $chld_in, my $chld_out, my $chld_err = Symbol::gensym(), @cmd);
      $result=<$chld_err>;
      close $chld_in;
      close $chld_out;
      close $chld_err;
      wait;
    };
    if(!$pid and $@){
      die "Error::Show failed to syntax check";
    }


  # 
  # 4. Status code from child indicates success
  # When 0 this means syntax was ok. Otherwise error
  # Attempt to propogate code to exit status
  #
  my $code=$?>255? (0xFF & ~$?): $?;

  my $runnable=$?==0;

  my $status=context(splain=>$splain, clean=>$clean, error=>$result )."\n";

  if($^C){
    if($runnable){
      #only print status if we want warnings
      print STDERR $do_warn?$status: "$file syntax OK\n";

    }
    else{
      #Not runnable, thus  syntax error. Always print
      print STDERR $status;

    }
    POSIX::_exit $code;

  }
  else{
    #not checking, we want to run
    if($runnable){
      # don't bother with warnings

      # v0.4.0
      # Install an global handler, unless asked not to
      #
      unless($no_handler){
        $SIG{__DIE__}=sub {
          # propagate eval and parsing errors
          die @_ if $^S or ! defined $^S;

          # Otherwise hard error
          my @frames;
          my $i=0;
          push @frames , [caller $i++] while caller $i;
          say STDERR Error::Show::context message=>$_[0], frames=>\@frames;
          exit;
        };
      }


    }
    else{
      #Not runnable, thus  syntax error. Always print
      print STDERR $status;
      POSIX::_exit $code;
    }
  }
}


sub process_string_error{
  my $error=shift;
  my %opts=@_;

	my @error_lines;
  my @errors; 
  #my @entry;
  my %entry;
	if(defined $error){
    #local $_=$error;
		#Substitue with a line number relative to the start marker
		#Reported line numbers are 1 based, stored lines are 0 based
    #my $translation=$opts{translation};
    #my $start=$opts{start};
  
    my $i=0;
		for(split "\n", $error){
      DEBUG and say STDERR "ERROR LINE: ".$_;
      if(/at (.*?) line (\d+)/
        or /Missing right curly or square bracket at (.*?) (\d+) at end of line/){
        #
        # Group by file names
        #
        DEBUG and say STDERR "PROCESSING: ".$_;
        DEBUG and say STDERR "file: $1 and line $2";
        my $entry=$entry{$1}//=[];
        #push @$entry, {file=>$1, line=>$2,message=>$_, sequence=>$i++};
        my $a=[];
        $a->[FILENAME]=$1;
        $a->[LINE]=$2-1;
        $a->[MESSAGE]=$_;
        $a->[MESSAGE]=$opts{message} if $opts{message};
        $a->[SEQUENCE]=$i++;
        $a->[EVALTEXT]=$opts{program} if $opts{program};
        push @$entry, $a;
      }
    }

    
	}
	else {
		#Assume a target line
    #push @error_lines, $opts{line}-1;
	}

  #Key is file name
  # value is a hash of filename,line number, perl error string and the sequence number

  \%entry;

}

# Takes a hash ref error sources

sub text_output {
  my $info_ref=pop;
  my %opts=@_;
  my $total="";
  DEBUG and say STDERR "Reverse flag in text output set to: $opts{reverse}";

  # Sort by sequence number 
  # Errors are stored by filename internally. Sort by sequence number.
  #

  my @sorted_info= 
    sort {$a->[SEQUENCE] <=> $b->[SEQUENCE] } 
    map {  $_->@* } values %$info_ref;

  # Reverse the order if we want the first error listed last
  #
  @sorted_info=reverse (@sorted_info) if $opts{reverse};

  # Process each of the errors in sequence
  my $counter=0;
  my $limit=$opts{limit}//100;
  for my $info (@sorted_info){
    last if $counter>=$limit and $limit >0;
    $counter++;
    unless(exists $info->[CODE_LINES]){
      my @code;
      
      if($info->[EVALTEXT]){
        @code=split "\n", $info->[EVALTEXT];
      }
      elsif(my @f=$info->[FILENAME] =~ /\(eval \d+\)/g){
        # Not actually a file, this was an eval
        @code=split "\n", $programs{$f[0]};
      }
      else {
        @code=split "\n", do {
          open my $fh, "<", $info->[FILENAME] or warn "Could not open file for reading: $info->[FILENAME]";
          local $/=undef;
          <$fh>;
        };
      }
      $info->[CODE_LINES]=\@code;
    }

    # At this point we have lines of code in an array
    #
    
    #Find start mark and end mark
    #
    my $start_line=0;
    if($opts{start_mark}){
      my $counter=0;
      my $start_mark=$opts{start_mark};
        for($info->[CODE_LINES]->@*){
          if(/$start_mark/){
            $start_line+=$counter+1;
            last;
          }
          $counter++;
        }
        # Don't include the start marker in the results
    }

    my $end_line=$info->[CODE_LINES]->@*-1;

    if($opts{end_mark}){
        my $counter=0;
        my $end_mark=$opts{end_mark};
        for (reverse($info->[CODE_LINES]->@*)){
          if(/$end_mark/){
            $end_line-=$counter;
            last;
          }
          $counter++;
        }
    }

    $start_line+=$opts{start_offset} if $opts{start_offset};
    $end_line-=$opts{end_offset } if $opts{end_offset};

    # preclamp the error line to within this range so that 'Unmatched ' errors
    # at least show ssomething.
    #
    $info->[LINE]=$end_line if $info->[LINE]>$end_line;

    DEBUG and say "START LINE after offset: $start_line";
    DEBUG and say "END LINE after offset: $end_line";
    # At this point the file min and max lines we should consider are
    # start_line and end line  inclusive. The $start_line is also used as an
    # offset to shift error sources
    #

    my $min=$info->[LINE]-$opts{pre_lines};
    my $max=$info->[LINE]+$opts{post_lines};

    my $target= $info->[LINE];#-$start_line;
    DEBUG and say "TARGET: $target";

    $min=$min<$start_line ? $start_line: $min;

    $max=$max>$end_line?$end_line:$max;

    #
    # format counter on the largest number to be expected
    #
    my $f_len=length("$max");

    my $indent=$opts{current_indent}//"";
    my $out="$indent$info->[FILENAME]\n";
    
    my $format="$indent%${f_len}d% 2s %s\n";
    my $mark="";

    #Change min and max to one based index
    #$min++;
    #$max--;
    DEBUG and say STDERR "min before print $min";
    DEBUG and say STDERR "max before print $max";
    for my $l($min..$max){
      $mark="";

      my $a=$l-$start_line+1;

      #Perl line number is 1 based
      $mark="=>" if $l==$target;


      # Print lines as per the index in file array
      $out.=sprintf $format, $a, $mark, $info->[CODE_LINES][$l];
    }

    $total.=$out;
    
    # Modifiy the message now with updated line numbers
    # TODO: Tidy this up
    $info->[MESSAGE]=~s/line (\d+)(?:\.|,)/(($1-1)>$max?$max:$1-1)-$start_line+1/e;

    $total.=$info->[MESSAGE]."\n" unless $opts{clean};

  }
  if($opts{splain}){
    $total=splain($total);
  }
  $total;
}


#Take an error string and attempt to contextualize it
#	context options_pairs, error string	
sub _context{
	#use feature ":all";
	DEBUG and say STDERR "IN context call";

  my $error=shift;

	my %opts=@_;

  # Get the all the info we need to process
  my $info_ref;
  if(defined($error) and ref($error) eq ""){
    #A string error. A normal string die/warn or compile time errors/warnings
    $info_ref=process_string_error $error, %opts;
  }
  else{
    #say STDERR "PROCESS_object ERROR $error";
    #Some kind of object, converted into line and file hash
    $info_ref= {$error->[FILENAME]=>[$error]};#  {$error->{file}=>[$error]};
    $error->[MESSAGE]=$opts{message}//""; #Store the message
    $error->[EVALTEXT]=$opts{program} if $opts{program};
  }
  
  # Override text/file to search
  my $output;
  $output=text_output %opts, $info_ref;
  
  #TODO:
  #
	$output;
  
}


#
# Front end to the main processing sub. Configures and checks the inputs
#
my $msg= "Trace must be a ref to array of  {file=>.., line=>..} pairs";
sub context{
  shift if(defined $_[0] and $_[0] eq __PACKAGE__);
  my %opts;
  my $out;
  my $do_internal_frames;
  if(@_==0){
    # use the $@  implicitly
    $opts{error}=$@;
  }
  elsif(@_==1){
    # Assume a string or object
    my $tmp=shift;
    #if(ref($tmp) eq "HASH"){
    if(Scalar::Util::blessed($tmp)//"" eq "Error::Show::Exception"){
      for my $k (keys $tmp->%*){
        $opts{$k}=$tmp->{$k};
      }
      $do_internal_frames=undef;
    }
    else {
      # Could be a string or other object
      $opts{error}=$tmp if defined $tmp;

      # Special case, backwards compat
      $do_internal_frames = !defined $opts{error};
    }
  }
  else {
    %opts=@_;
  }

  return unless $opts{error} or $opts{frames} or $do_internal_frames;

  #$opts{start_mark};#//=qr|.*|;	#regex which matches the start of the code 
	$opts{pre_lines}//=5;		  #Number of lines to show before target line
	$opts{post_lines}//=5;		#Number of lines to show after target line
	$opts{start_offset}//=0;	#Offset past start mark to consider as min line
	$opts{end_offset}//=0;		#Offset before end to consider as max line
	$opts{translation}//=0;		#A static value added to the line numbering
	$opts{indent}//="    ";
	$opts{file}//="";

  ########################################
  # if($opts{frames}){                   #
  #   $opts{error}=delete $opts{frames}; #
  # }                                    #
  ########################################

  # For the special case of error undefined, we assume we want to dump the current location/context
  #
  if($do_internal_frames){
    my $i=0;

    #build call frames
    my @frame;
    my @stack;

    while(@frame=caller($i++)){
       push @stack, [@frame];
    }
    $opts{frames}=\@stack;
  }
  
  # Convert from supported exceptions classes to internal format
  my $ref=ref $opts{frames};
  my $dstf="Devel::StackTrace::Frame";

  require Scalar::Util;
  if((Scalar::Util::blessed($opts{frames})//"") eq $dstf){
    # Single DSTF stack frame. Convert to an array
    $opts{frames}=[$opts{frames}];
  }
  elsif($ref eq "ARRAY" and ref($opts{frames}[0]) eq ""){
    # Array of scalars  - a normal stack frame - wrap it
    $opts{frames}=[[$opts{frames}->@*]];
  }
  elsif($ref eq ""){
    # Not a reference - A string error 
  }
  elsif($ref eq "ARRAY" and ref($opts{frames}[0]) eq "ARRAY"){
    # Array of  arrays of scalars
    $opts{frames}=[map { [$_->@*] } $opts{frames}->@* ];
    
  }
  elsif($ref eq "ARRAY" and Scalar::Util::blessed($opts{frames}[0]) eq $dstf){
    #Array of DSTF object
  }

  $opts{message}//="@{[$opts{error}//'']}";
  

  $opts{current_indent}="";
  my $current_indent="";
  # Show the actual error 
  my $info_ref=process_string_error $opts{error}, %opts ;
  $out=text_output %opts, $info_ref;
  $opts{current_indent}.=$opts{indent};


  DEBUG and say STDERR "Reverse flag set to: $opts{reverse}";

  # Reverse the ordering of errors here if requested
  #
  $opts{frames}->@*=reverse $opts{frames}->@* if $opts{reverse};
  # Check for trace kv pair. If this is present. We ignore the error
  #
  if(ref($opts{frames}) eq "ARRAY" and ref $opts{frames}[0]){
    # Iterate through the list

    #my %_opts=%opts;
    $opts{clean}=1;
    my $i=0;  #Sequence number
    for my $e ($opts{frames}->@*) {

      if((Scalar::Util::blessed($e)//"") eq "Devel::StackTrace::Frame"){
        #Convert to an array
        my @a;
        $a[PACKAGE]=$e->package;
        $a[FILENAME]=$e->filename;
        $a[LINE]=$e->line;
        $a[SUBROUTINE]=$e->subroutine;
        $a[HASARGS]=$e->hasargs;
        $a[WANTARRAY]=$e->wantarray;
        $a[EVALTEXT]=$e->evaltext;
        $a[IS_REQUIRE]=$e->is_require;
        $a[HINTS]=$e->hints;
        $a[BITMASK]=$e->bitmask;
        $a[HINT_HASH]=$e->hints;
        $e=\@a;
      }


      if($e->[FILENAME] and defined $e->[LINE]){
        $e->[MESSAGE]//="";

        #Force a message if one is provided
        $e->[LINE]--; #Make the error 0 based
        $e->[MESSAGE]=$opts{message} if $opts{message};
        $e->[SEQUENCE]=$i++;
        
        # Generate the context here
        #
        #$_opts{indent}=$current_indent;
        #$_opts{error}=$e;
        $out.=_context $e, %opts;
        $opts{current_indent}.=$opts{indent};
      }
      else{
        die $msg;
      }
    }

  }
  ########################################
  # else {                               #
  #   $out=_context $opts{error}, %opts; #
  # }                                    #
  ########################################
  $out;
}



my ($chld_in, $chld_out, $chld_err);
my @cmd="splain";
my $pid;

sub splain {
  my $out;
  #Attempt to open splain process if it isn't already
  unless($pid){
    eval{
      $pid= IPC::Open3::open3($chld_in, $chld_out, $chld_err = Symbol::gensym(), @cmd);
      #$chld_in->autoflush(1);

    };
    if(!$pid and $@){
      warn "Error::Show Could not splain the results";
    }
  };

  #Attempt to write to the process and read from it
  eval {
    print $chld_in $_[0], "\n";;
    close $chld_in;
    $out=<$chld_out>;
    close $chld_out;
    close $chld_err;
  };

  if($@){
    $pid=undef;
    close $chld_in;
    close $chld_out;
    close $chld_err;
    warn "Error::Show Could not splain the results";
  }
  $out;
}

sub streval ($;$){

  # The program we want to execute
  my $code= $_[0];
  if(ref($code) eq "CODE"){
    return eval {$code->()};
  }
  my $package=$_[1]//caller;


  # Wrap the eval in a sub. Here we can seperate syntax/complile errors and run
  # time errors
  #

  my $file;

  # Do eval to get current eval number and then calculate the NEXT eval number
  my $number=eval '__FILE__=~ qr/(\d+)/; $1';
  $number++;
  $file="(eval $number)"; 
  my @in_sub_frame;
  # Attempt to compile 
  #
  my $sub;
  {
    local $@;
    #$sub=eval "sub {package $package; \@in_sub_frame=caller(0); local \$@; my \@res=eval {$code}; if(\$@){} \@res}";
    $sub=eval "sub {package $package; \@in_sub_frame=caller(0); $code}";

    # Check for SYNTAX error
    #
    my $error=$@;
    if(!defined($sub) or $error){
      # extract the filename (including the () )stored in the error 
      my $filename= $error=~/\(eval \d+\)/g;

      my @frame;
      my @stack;

      my $i=1;
      push @stack, [@frame];   #frame from actual eval
      while(@frame=caller($i++)){
        push @stack, [@frame];
      }
      die {error=>$error, frames=>\@stack};
    }
  }
  $programs{$file}=$code;


  my $result;
  { 
    # Check for RUNTIME error
    local $@;
    my @frame;
    $result=eval { $sub->(); };
    my $error=$@;
    if($error){
      if(!ref $error){
        # extract the filename stored in the error  string
        my $filename= $error=~/\(eval (\d+)\)/g;
        my @stack;
        my $i=1;
        push @stack, [@in_sub_frame];   #frame from actual eval
        while(@frame=caller($i++)){
          push @stack, [@frame];
        }

        my $o=bless {error=>$error, frames=>\@stack}, "Error::Show::Exception";
        die $o;
      }
      else {
        # Rethrow as is
        die $error;
      }
    }
  }

  # otherwise return the result
  $result;
}

sub throw {
  my $error=shift;
  $error//=$@;
  my @c=caller(0);
   
  my @frames;
  my $i=1;
  while(my @frame=caller($i++)){
    push @frames, \@frame;
  }

  unless(ref $error){
    # Error is just a string. so we re create the file and line number 
    # from the the caller this sub
    # 
    die bless {error=>"$error at $c[1] line $c[2]", frames=>\@frames}, "Error::Show::Exception";
  }
  else {
    die bless {error=>$error, frames=>\@frames}, "Error::Show::Exception";
  }
}

package Error::Show::Exception;
use overload 
  '""'=>sub { "$_[0]{error}" },
  'eq'=>sub { "$_[0]{error}" eq $_[1] };

1;
__END__
