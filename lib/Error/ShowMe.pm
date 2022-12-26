package Error::ShowMe;

use 5.024000;
use strict;
use warnings;

#use Exporter qw<import>;
use base "Exporter";


our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} });

our @EXPORT = qw(

	
);
my @valid_errors=(
	"Can't find string terminator"
);

our $VERSION = '0.01';
use constant DEBUG=>0;
use IPC::Open3;
use Symbol 'gensym'; # vivify a separate handle for STDERR

sub context;
#A list of top level file paths or scalar refs to check for syntax errors

my @IINC;
sub import {
	my $package=shift;
	my @caller=caller;
	my %options=@_;
	if($caller[2]){
		#A nonzero line means included in code, not from command line
		#process export requests

		return;
	}
	

	#need to find out the any extra lib paths used. Fork and print out the defaults
	#Only run it the first time its used
	@IINC=map {chomp; $_} do {
		open my $fh, "-|", $^X . q| -E 'map print("$_\n"), @INC'| or die "$!";
		<$fh>;
	} unless @IINC;

	#Extract the extra include paths
	my @extra=map  {("-I", $_)} grep {my $i=$_; !grep { $i eq $_} @IINC} @INC;


	local $/=undef;
	for my $file($0, @ARGV){
		next unless -f $file;
		my @cmd= ($^X , @extra, "-c",  $file);
		#print "COMMand: ".join(" ", @cmd)."\n";

		my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym, @cmd);
		my $result=<$chld_err>;
		close $chld_in;
		close $chld_out;
		close $chld_err;
		wait;

		print STDERR context(error=>$result, $file)."\n";
	}
	exit;
}

#Take an error string and attempt to contextualize it
#	context options_pairs, error string	
sub context{
	#use feature ":all";
	DEBUG and say STDERR "IN context call";
	my ($package, $file, $caller_line)=caller;

	my $program=pop(@_);	#Program is the last argument
	$program//=$file; 	#Or use the caller if it is undefined

	#return if ref $error;	#Only want to handle syntax errors?
	
	my %opts=@_;

	#Error is set by hash or not supplied tries the $@ variable
	my $error= $opts{error}//$@;
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

	#$min-=1;
	#$max-=1;

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

sub trace_context {
	#my $program=pop;
	my %opts=@_;
	my $_indent=$opts{indent}//="    ";

	$opts{error}//=$@;
	my @caller;
	my $i=0; #skip the call to this sub
	my @frames;
	while(@caller=caller($i++)){
		push @frames,[@caller];
	}
	my $out="";
	@frames =reverse @frames;
	my $current_indent="";
	for my $caller (@frames){
		$opts{line}=$caller->[2];
		$opts{indent}=$current_indent;
		$out.=context %opts, $caller->[1];
		$out.="\n";
		$opts{error}=undef;
		$current_indent.=$_indent;
	}
	$out;
}

1;
__END__
