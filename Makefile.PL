use 5.024000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Error::ShowMe',
    VERSION_FROM      => 'lib/Error/ShowMe.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/Error/ShowMe.pm', # retrieve abstract from module
    AUTHOR            => 'Ruben Westerberg <drclaw@mac.com>',
    LICENSE           => 'mit',
    #Value must be from legacy list of licenses here
    #https://metacpan.org/pod/Module::Build::API
);