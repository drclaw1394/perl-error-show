package Error::Show;

use 5.024000;
use strict;
use warnings;

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
  $options{check}=grep /check/, @options;
  $options{format}=grep /json/, @options;
	
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

  my $runnable=not $options{check};
  #for my $file(@file){
		next unless -f $file;
		my @cmd= ($^X , @extra, "-c",  $file);

		my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym, @cmd);
		my $result=<$chld_err>;
		close $chld_in;
		close $chld_out;
		close $chld_err;
		wait;

    my $status=context(error=>$result, program=>$file)."\n";

    #
    # Report file syntax status unless stealth was specified
    #
		print STDERR $status;

    #
    # Mask runnable 
    #
    $runnable&&=$status =~ /syntax OK/;
    
    #}

  #
  # 4. Conditional Execution
  # 
  # Unless the -c option was specified, or more than one source file, continue
  # the execution of the script
  #

  exit unless $runnable;

}

#Take an error string and attempt to contextualize it
#	context options_pairs, error string	
sub context{
	#use feature ":all";
	DEBUG and say STDERR "IN context call";
	my ($package, $file, $caller_line)=caller;

	# 
  # Error is set by single argument, key/value pair, or if no
  # argument $@ is used
  #
  my $error;

  if(@_==0){
    $error=$@;
  }
  elsif(@_==1){
    $error=shift;
  }

  my $program;

  #	
  # Remaining arguments are to be key/value options
  #
	my %opts=@_;
	$error//= $opts{error};

  $program=$opts{program};

  # 
  # If no program has been specifed yet, attempt to extract from the actual
  # error message.
  #
  unless($program){
    my $ref=ref $error;
    unless($ref){
      ($program, undef)=split "/n", $error, 2 unless($program);

      chomp $program;
      #
      # Compile time errors list filename on first line by itself
      # Run time exceptions will have the location informaiton appended to the line
      # for normal string exceptions(die) and actual exceptions (eg divide by
      # zero).
      # However If the message has a newline or is an ref or object, then the
      # location information  is not appended and manual manipulation is required.
      #
      if($program=~/at (.*) line (\d+)\.$/){
        # Runtime error/exception
        $program=$1;
      }
      else {
        #compile time
      }
    }
    else {
      #Assume an object with __FILE__ and __LINE__
      $program=$opts{file}=$error->file;
      $opts{line}=$error->line;
    }
  }

  #$program//=$file; 	#Or use the caller if it is undefined

	$error=undef if defined $opts{line};

	return unless $error or $opts{line};
	$opts{start_mark}//=qr|.*|;	#regex which matches the start of the code 
	$opts{pre_lines}//=5;		#Number of lines to show before target line
	$opts{post_lines}//=5;		#Number of lines to show after target line
	$opts{offset_start}//=0;	#Offset past start to consider as min line
	$opts{offset_end}//=0;		#Offset before end to consider as max line
	$opts{translation}//=0;		#A static value added to the line numbering
	$opts{indent}//="";
	$opts{file}//="";


	my $prog;
	if(ref($program)){
		$prog=$$program;	
		$opts{file}//="EVAL";
	}
	elsif($program){
    return $error unless -f $program; #Abort if we can't access the file
		#file path
		$prog=do {
			open my $fh, "<", $program or die "Could not open file for reading";
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
	#TODO: only need to process pre_lines+1+post_lines  instead of the hole file....
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

		return "$program syntax OK" unless @error_lines;
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
	if(defined $error){
		$out.=join "\n", 
		map {$opts{indent}.$_ }
		split "\n", $error;
		$out.="\n";
	}
	
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

	DEBUG and say STDERR "TRANSFORMED: $out";
	$out
}
sub tracer{
  my $trace;
  if(@_==0){
    $trace=$@->trace;
  }
  elsif(@_==1){
    $trace=shift;
    unless(ref($trace) eq "Devel::TraceStack"){
      $trace=$trace->trace;
    }
  }
  my %opts=@_;
  $trace//=$opts{trace};#Devel::StackTrace;
  $trace//=$opts{error}->trace;
	my $_indent=$opts{indent}//="    ";
	my $current_indent="";
  # from top (most recent) of stack to bottom.
  my $out="";
  while ( my $frame = $trace->prev_frame ) {
		  $opts{indent}=$current_indent;
      $out.=context %opts, program=>$frame->filename, line=>$frame->line;
		  $current_indent.=$_indent;
  }
  $out;
}

1;
__END__
