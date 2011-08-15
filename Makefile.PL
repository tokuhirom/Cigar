use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Cigar',
    AUTHOR        => 'tokuhirom <person@example.com>',
    VERSION_FROM  => 'cigar.pl',
    PREREQ_PM     => {
    },
    MIN_PERL_VERSION => '5.008001',
    (-d 'xt' and $ENV{AUTOMATED_TESTING} || $ENV{RELEASE_TESTING}) ? (
        test => {
            TESTS => 't/*.t xt/*.t',
        },
    ) : (),
);
