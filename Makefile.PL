use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Cigar',
    AUTHOR        => 'tokuhirom <person@example.com>',
    VERSION_FROM  => 'bin/cigar.pl',
    PREREQ_PM     => {
    },
    MIN_PERL_VERSION => '5.008001',
	EXE_FILES => [ 'bin/cigar.pl' ],
    (-d 'xt' and $ENV{AUTOMATED_TESTING} || $ENV{RELEASE_TESTING}) ? (
        test => {
            TESTS => 't/*.t xt/*.t',
        },
    ) : (),
);
