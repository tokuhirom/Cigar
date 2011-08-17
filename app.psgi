use strict;
use warnings;
use Plack::Builder;
use Plack::Request;
use Plack::App::Directory;
use HTML::Entities;

my $root = $ENV{CIGAR_ROOT};
die "please set \$ENV{CIGAR_ROOT}" unless $root;

builder {
    enable 'ContentLength';
    mount '/' => sub {
        my $env = shift;
        if ($env->{PATH_INFO} eq '/') {
            return [200, [], [<<'...']];
<!doctype html>
<html>
    <head><title>Cigar</title></head>
    <body>this is a cigar server</body>
</html>
...
        } else {
            return [404, [], ['Not found']];
        }
    };
    mount '/logs' => Plack::App::Directory->new({root => "$root/logs"});
};

