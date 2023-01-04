package Error::Show;

use 5.024000;
use strict;
use warnings;
use Carp;
use POSIX;  #For _exit;

#use Exporter qw<import>;
use base "Exporter";


our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} });

our @EXPORT = qw();

my @valid_errors=(
	"Can't find string terminator"
);

our $VERSION = 'v0.1.0';
use constant DEBUG=>0;
use IPC::Open3;
use Symbol 'gensym'; # vivify a separate handle for STDERR

sub context;

#
# A list of top level file paths or scalar refs to check for syntax errors
#
my @IINC;


 
sub import {
  my $package=shift;
  my @caller=caller;
  my @options=@_;


  if($caller[2]){
    # 
    # A nonzero line means included in code, not from command line, 
    # process export requests.
    #
    return;
  }

  # 
  # CLI Options include 
  #   check  =>  check only
  #   json    =>  output as json instead of normal errors
  my %options;
  #$options{check}=grep /check/, @options;
  my $clean=grep /clean/, @options;


  # Process with warnings if specified
  #my $do_warn=$^W|| grep /warn/, @options;

  my $do_warn=$^W||${^WARNING_BITS};

  ###########################################################
  # say "^W: ".$^W;                                         #
  # say "^S: ".$^S;                                         #
  # say "Warning bits: ".${^WARNING_BITS};                  #
  # say "check flag: $^C";                                  #
  # say "Defined warning bits ". defined(${^WARNING_BITS}); #
  ###########################################################
  
  my @warn;
  if(${^WARNING_BITS}){
    #defined true  value  
    @warn=("-W");
  }
  elsif(defined(${^WARNING_BITS})){
      #defined value only
      @warn=("-X");
  }
  elsif($^W){
    #If still checking, this is set with the -w flag
    @warn=("-w");
  }
  else{
    #no -w -W or -X flags set
  }


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
  die "Sorry, cannot Error::Show \"$file\"" unless -f $file;
  my @cmd= ($^X ,@warn, @extra, "-c",  $file);

  my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym, @cmd);
  my $result=<$chld_err>;
  close $chld_in;
  close $chld_out;
  close $chld_err;
  wait;

  # 
  # 4. Status code from child indicates success
  # When 0 this means syntax was ok. Otherwise error
  # Attempt to propogate code to exit status
  #
  my $code=$?>255? (0xFF & ~$?): $?;

  my $runnable=$?==0;
  #say "SYNTAX RUNNABLE: $runnable";

  my $status=context(clean=>$clean, error=>$result, program=>$file)."\n";

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

    }
    else{
      #Not runnable, thus  syntax error. Always print
      print STDERR $status;
      POSIX::_exit $code;
    }
  }
}

#Take an error string and attempt to contextualize it
#	context options_pairs, error string	
sub context{
	#use feature ":all";
	DEBUG and say STDERR "IN context call";
  #my ($package, $file, $caller_line)=caller;
	# 
  # Error is set by single argument, key/value pair, or if no
  # argument $@ is used
  #
  my $error;
	my %opts=@_;

  if(@_==0){
    $error=$@;
  }
  elsif(@_==1){
    $error=shift;
  }
  else {
	  $error= $opts{error};
  }

  my $program;

  #	
  # Remaining arguments are to be key/value options
  #

  # 
  # Program is the original application file or string ref
  #
  $program=$opts{program};

  # 
  # If no program has been specifed yet, attempt to extract from the actual
  # error message.
  #
  #unless($program){


  # 
  # If we have an error stirng/object extract what we need
  #
  if($error){
    my $ref=ref $error;

    unless($ref){
      my $first="";
      ($first)=split "\n", $error;

      chomp $first;
      #
      # Compile time errors list filename on first line by itself
      # Run time exceptions will have the location informaiton appended to the line
      # for normal string exceptions(die) and actual exceptions (eg divide by
      # zero).
      # However If the message has a newline or is an ref or object, then the
      # location information  is not appended and manual manipulation is required.
      #
      if($first=~/at (.*) line (\d+)/){
        # Runtime error/exception
        #$program=
        $opts{file}=$1;
        $opts{line}=$2;
      }
      else {
        #Assume no error
      }
    }
    else {
      #Assume an object with __FILE__ and __LINE__
      #$program=
      $opts{file}=$error->file;
      $opts{line}=$error->line;
    }
  }
  else {
      #Assume the line and file are specified manually
	    $error=undef;# if defined $opts{line};
  }

  #$program//=$file; 	#Or use the caller if it is undefined


	return unless $error or $opts{line};
	$opts{start_mark}//=qr|.*|;	#regex which matches the start of the code 
	$opts{pre_lines}//=5;		#Number of lines to show before target line
	$opts{post_lines}//=5;		#Number of lines to show after target line
	$opts{offset_start}//=0;	#Offset past start to consider as min line
	$opts{offset_end}//=0;		#Offset before end to consider as max line
	$opts{translation}//=0;		#A static value added to the line numbering
	$opts{indent}//="";
	$opts{file}//="";

  #
  # Here we want to read the file with the error in it. This might not
  # be the program file specified, but a module
  #
	my $prog="";
	if(ref($program)){
		$prog=$$program;	
		$opts{file}//="EVAL";
	}
	elsif($opts{file}){
    return $error unless -f $opts{file}; #Abort if we can't access the file
		#file path
		$prog=do {
			open my $fh, "<", $opts{file} or die "Could not open file for reading";
			local $/=undef;
			<$fh>;
		};
    $opts{file}||=$program;	#set filename
	}
	else {
		#Use caller?
	}

	my $line=0;
	my $start=undef;
	$start=0 if defined($opts{line});

	
	#Break up error message into lines
	#TODO: only need to process pre_lines+1+post_lines  instead of the whole file....
	my @lines=map { $start = $line++ if !defined($start) .. /$opts{start_mark}/;$_."\n" } split "\n", $prog;
	
	DEBUG and say STDERR "LINES:\n", @lines;

	#$start+=2;
	my @error_lines;
	if(defined $error){
		local $_=$error;
		#Substitue with a line number relative to the start marker
		#Reported line numbers are 1 based, stored lines are 0 based
		my $translation=$opts{translation};
		$error=~s/line (\d+)/do{push @error_lines, $1-1+$translation;"line ".($1-$start+$translation)}/eg;
		$error=~s/\(eval (\d+)\)/"(".$opts{file}.")"/eg;

    
		return "$program syntax OK" if $program and !@error_lines;
		@error_lines=(shift @error_lines);
	}
	else {
		#Assume a target line
		push @error_lines, $opts{line}-1;
	}

	my $min=$error_lines[0];
	my $max=$error_lines[0];

	$min>$_ and $min=$_ for @error_lines;
	$max<$_ and $max=$_ for @error_lines;


	#Adjust start and end posision with offset
	$start+=$opts{offset_start};
	my $end=$#lines -$opts{offset_end};

	#Set context start and stop line numbers and clamp if out of range of the file
	$min-=$opts{pre_lines}; $min=$start if $min<$start;
	$max+=$opts{post_lines}; $max=$end if $max>$end;
	
	#my $counter=$min;	#counter is translated  line count

	#format counter on the largest number to be expected
	my $f_len=length("$max");

	my $out="$opts{indent}$opts{file}\n";
  $out.="\n";
	
	my $indent=$opts{indent}//"";
	my $format="$indent%${f_len}d% 2s %s";
	my $mark="";

	DEBUG and say STDERR "Error lines: ", join ", ", @error_lines;
	DEBUG and say STDERR "Lines: ", @lines;
	DEBUG and say STDERR "MIN: $min, MAX: $max";
	#my $translation=$opts{translation}+1;
	for my $l($min..$max){
		$mark="";
		$mark="=>" if(grep {$l==$_} @error_lines);
		$out.=sprintf $format, $l+1, $mark, $lines[$l];

	}

  unless($opts{clean}){
    $out.="\n";

    if(defined $error){
      $out.=join "\n", 
      map {$opts{indent}.$_ }
      split "\n", $error;
      $out.="\n";
    }
  }

	DEBUG and say STDERR "TRANSFORMED: $out";
	$out
}


#
# This only works with errors objects which captured a trace as a Devel::StackTrace object
#
sub tracer{
  my $trace;
  my $error;
  my %opts;
  if(@_==0){
    $opts{error}=$@;
  }
  elsif(@_==1){
    $opts{error}=shift;
  }
  else {
    %opts=@_;
  }

  if(ref($opts{error})){
    $@=undef;
    eval {
        $opts{trace}=$opts{error}->trace;
    };
    if($@){
        carp "Could not call trace method on error (error not an object?)";
        return "";
    }
  }
  else {
    if (ref($opts{trace}) ne "Devel::StackTrace"){
      
      carp "Error does not have trace or is not a Devel::TraceStack object";
      return "";
    }
  }



  $error=delete($opts{error})//"";
  $trace=$opts{trace};
  $opts{clean}=1;   #for clean

	my $_indent=$opts{indent}//="    ";
	my $current_indent="";
  # from top (most recent) of stack to bottom.
  my $out="";
  while ( my $frame = $trace->prev_frame ) {
		  $opts{indent}=$current_indent;
      $out.=context %opts, file=>$frame->filename, line=>$frame->line;
		  $current_indent.=$_indent;
  }
  
  $out.=$error;
  #$out;
}

1;
__END__
