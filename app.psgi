use strict;
use warnings;
use Plack::Builder;
use Plack::Request;
use HTML::Entities;

my $root = $ENV{CIGAR_ROOT};
die "please set \$ENV{CIGAR_ROOT}" unless $root;

builder {
    enable 'ContentLength';
    sub {
        my $env = shift;
        if ($env->{PATH_INFO} eq '/') {
            return [200, [], [<<'...']];
<!doctype html>
<html>
    <head><title></title></head>
    <body>this is a cigar server</body>
</html>
...
        } elsif ($env->{PATH_INFO} =~ m{^/logs/([A-Za-z0-9_-]+.txt)$}) {
            my $fname = File::Spec->catfile( $root, 'logs', $1 );
            open my $fh, '<', $fname or die "cannot open $fname: $!";
            my $content = do { local $/; <$fh> };
            return [200, [], [sprintf(<<'...', $1, $content)]];
<!doctype html>
<html>
    <head><title>Test result: %s</title></head>
    <body><pre>%s</pre></body>
</html>
...
        } else {
            return [404, ['Content-Type' => 'text/plain'], ['not found']];
        }
    };
};
