# NAME

Error::Show - Show context of syntax errors and exceptions

# SYNOPSIS

From the command line changes an error like this:

```perl
->perl examples/file_syn_error1.pl              
"use" not allowed in expression at examples/file_syn_error1.pl line 9, at end of line
syntax error at examples/file_syn_error1.pl line 9, near "adf
use Socket"
Execution of examples/file_syn_error1.pl aborted due to compilation errors.
```

To something a little more helpful, with no modifications:

```perl
->perl  -MError::Show examples/file_syn_error1.pl
examples/file_syn_error1.pl

 4   my $time=time;
 5   for(1..1000){
 6    print "$_\n";
 7   }
 8   adf
 9=> use Socket;
10   
11   print "this will never work";

"use" not allowed in expression at examples/file_syn_error1.pl line 9, at end of line
syntax error at examples/file_syn_error1.pl line 9, near "adf
use Socket"
examples/file_syn_error1.pl had compilation errors.

```

To only perform a syntax check only (no run):

```
    perl -MError::Show=check examples/file_syn_error1.pl 
```

Works with other perl flags and arguments:

```perl
    perl -I my_lib -MError::Show -MAnother::Module  path/to/file.pl
```

Use at runtime to supplement exception handling:

```perl
use Error::Show;

#an die caught in a try/eval triggers an exception

#No argument uses $@ as error
say STDERR Error::Show;     

#or a single exception argument of your choosing
say STDERR Error::Show $@;  

#Or customise the report format, line, program information
say STDERR Error::Show line=>123, ... , error=>$e;
```

Generate context for your stack traces with [Exception::Class::Base](https://metacpan.org/pod/Exception%3A%3AClass%3A%3ABase):

```perl
#supports no argument ($@), single argument or option pairs as
#Error::Show::context does
say STDERR Error::Show::tracer error=>$e;
```

Or supply a [Devel::StackTrace](https://metacpan.org/pod/Devel%3A%3AStackTrace) object directly 

```perl
say STDERR Error::Show::tracer trace=>$my trace;
  
```

# DESCRIPTION

This module aids in debugging and processing exceptions and errors in your
code. It does this in two modes of operation:

- 1. Syntax checking with contextual information

    This is done at compile time from the command line. No modifications to existing
    code are required. Very handy!

    ```
    perl -MError::Show  path_to_your_script
    ```

    This will execute your script if no syntax problems where found, or it will
    display the code context of the error.

- 2. Exception supplimental contextual information

    Interoperates with perl 'basic string' exceptions and CPAN exception modules
    ([Exception::Class::Base](https://metacpan.org/pod/Exception%3A%3AClass%3A%3ABase) or [Exception::Base](https://metacpan.org/pod/Exception%3A%3ABase) are recommended by not
    required) to provide additional information (i.e. code context) of an
    exception.

This **is not** an exception base class, but can operate with object exceptions.
The only requirement is the exception object responds to stringifcation and has
a `file` and `line` method. A `trace` method (returning a
[Devel::StackTrace](https://metacpan.org/pod/Devel%3A%3AStackTrace) object is also required for the  `Error::Show::trace`
function to work as intended.

The information generates can be though of as an expanded stack trace. Instead
of just the function name and location generated in a normal stack trace, the
actual lines of code are also reported.

A handful of options provided basic configuration of how many lines of code to
print before and after the target line, indenting  prefix etc.

No symbols are exported and as such they must be accesses via the package name.

# WHY USE THIS MODULE?

- 1. Small and fast

    [Perl::Critic](https://metacpan.org/pod/Perl%3A%3ACritic) is a fine tool. But it is large and complex and is focused on
    your style and not syntax errors. Perl obviously tells you about syntax errors,
    but this modules just makes it a little nicer to visualise.

- 2. No dependencies

    If your code doesn't compile, you can't use a custom exception class can you?
    This will provide context information on syntax error directly from the command
    line and doesn't need to be a dependency of your code. It also does not require
    any Exception modules.

- 3. Doesn't force a philosophy

    Equally important, this module doesn't get in the way of using nice exception
    classes during run time. It supplements them. You can choose when to use it to
    aid in debugging or error reporting.

# USAGE

## Command Line usage (Syntax checking)

```
    perl -MError::Show  file.pl 
```

When included in a command line switch to perl `-MError::Show`, it syntax
checks the input program. If the syntax is good, normal execution continues.
Otherwise detailed code context surrounding the source of the error is
generated and printed on STDERR.

**NOTE:**It is important that it's the first `-M` switch.

Additional `@INC` directories and perl switches can also be used as per
normal.

**Syntax Checking Options**

#### check

If you are only requiring syntax checking (no execution), specify the **check**
option:

```
perl -MError::Show=check file.pl
```

#### clean

If you prefer just the code context without the perl error,  add the clean
option

```
perl -MError::Show=clean file.pl
```

## Exception (in program) Usage

Simply bring [Error::Show](https://metacpan.org/pod/Error%3A%3AShow) into your program with a use statement:

```perl
    use Error::Show;
```

### Error::Show::context

```perl
my $context=Error::Show::context;                     (1)
my $context=Error::Show::context $error;              (2)
      my $context=Error::Show::context option_pairs, ...;   (3)
      
```

Takes an error string, or exception object and extracts the code surrounding
the source of the error. 

Return value is original error stringified with the formatted multi line string
of code, with prefixed line numbers, and a 'fat arrow' maker indicating the
line which causes the error to occur:

```perl
filename.pl 
... error... at filename.pl line 12 ...
10  #code before 
11  #code before 
12=>#this line caused the error
13  #code after
14  #code after
```

In the first form (1), the `$@` variable is implicitly used as the error. No
processing options can be supplied in this form.

In the second form (2), a single argument is supplied, which becomes the error
to process. No processing options can be supplied in this form.

In the third for (3), all options are provided as key value pairs. The required
key is **error**,with a value corresponding to the error value.

Internally if the error is a simple perl string, the **program** and **line**
options are extracted from the error string. If the error is a reference, it is
expected to be an object responding to stringificaton, file, and line methods.
[Exception::Base](https://metacpan.org/pod/Exception%3A%3ABase) and [Exception::Class::Base](https://metacpan.org/pod/Exception%3A%3AClass%3A%3ABase)  provides this interface for
example.

**Options include:**

#### program

```perl
program => $path
program => \$string
```

Manual override of the program source file. If the value is a normal scalar, it
is treated as a path. If it is a reference, it is treated as a reference to the
body of the program stored in a string.

#### line

```perl
line=>value
```

Manual override of the line number within the program where the error occurred.

#### pre\_lines

```perl
pre_lines=>value
```

Specific the maximum lines of code to display before the error line. Default is
5.

#### post\_lines

```perl
post_lines=>value
```

Specific the maximum lines of code to display after the error line. Default is
5.

#### clean

```perl
clean=>bool
```

When true, the normal perl error string is not included in the context
information, for a cleaner look.

### Error::Show::tracer

```
Error::show::tracer;                    (1)
Error::show::tracer $error; (2)
      Error::Show::tracer option_pairs;       (3)
```

Repeatedly calls `Error::Show::context` for each level the call stack
represented by a [Devel::StackTrace](https://metacpan.org/pod/Devel%3A%3AStackTrace) object.  Takes the same option pairs as
[Error::Show::context](https://metacpan.org/pod/Error%3A%3AShow%3A%3Acontext).

It forces the **clean** option for each level of stack trace. The stringified
error is appended at the end.

**NOTE:**This assumes the error input is an object that responds to the **trace**
method and not a simple perl string error. See the trace option below.

**Additional Options:**

#### indent

```perl
indent=>string
```

The string to use for each level of indent. Defaults to 4 spaces.

#### trace

```perl
trace=>devel_stack_trace
```

Instead of specifying the error option, the trace option allows specifying
directly the [Devel::StackTrace](https://metacpan.org/pod/Devel%3A%3AStackTrace) object to use.

# EXAMPLES

Please see the examples directory in this distribution

# FUTURE WORK/TODO

- Make usable from a Language Server?
- Colour terminal output

# SEE ALSO

[Perl::Syntax](https://metacpan.org/pod/Perl%3A%3ASyntax) provides syntax checking from the command line. However it
doesn't show any errors by design (only interested in process return code)

[Syntax::Check](https://metacpan.org/pod/Syntax%3A%3ACheck) provides programmatic syntax checking of files.

[Perl::Critic](https://metacpan.org/pod/Perl%3A%3ACritic) gives actual perl linting, but not great for syntax errors.

# AUTHOR

Ruben Westerberg, <drclaw@mac.com>

# REPOSITORTY and BUGS

Please report any bugs via git hub:
[http://github.com/drclaw1394/perl-error-show](http://github.com/drclaw1394/perl-error-show)

# COPYRIGHT AND LICENSE

Copyright (C) 2022 by Ruben Westerberg

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl or the MIT license.

# DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS
OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE.
