use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Cigar',
    AUTHOR        => 'tokuhirom <person@example.com>',
    VERSION_FROM  => 'bin/cigar.pl',
    PREREQ_PM     => {
		'LWP::UserAgent' => 0,
		'Time::Piece'    => 0,
		'Plack'          => 0, # for web view
		'HTML::Entities' => 0,
    },
    MIN_PERL_VERSION => '5.008001',
	EXE_FILES => [ 'bin/cigar.pl' ],
    (-d 'xt' and $ENV{AUTOMATED_TESTING} || $ENV{RELEASE_TESTING}) ? (
        test => {
            TESTS => 't/*.t xt/*.t',
        },
    ) : (),
);
