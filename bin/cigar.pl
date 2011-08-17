#!/usr/local/bin/perl
use strict;
use warnings;
use utf8;
use 5.008008;

package App::Cigar;
our $VERSION = '0.01';
use Carp ();
use File::Spec;
use File::Path qw(mkpath);
use LWP::UserAgent;

sub base { $_[0]->{base} }
sub branch { $_[0]->{branch} }
sub repo { $_[0]->{repo} }
sub ikachan_url { $_[0]->{ikachan_url} }
sub ikachan_channel { $_[0]->{ikachan_channel} }

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;

    for my $k (qw(base branch repo)) {
        unless (defined $args{$k}) {
            Carp::croak("missing mandatory parameter: $k");
        }
    }

    bless { %args }, $class;
}

sub run {
    my $self = shift;

    my $branch = $self->branch;

    my $fail = 0;

    $self->log("start testing");

    {
        mkpath($self->base);
        chdir($self->base) or die "Cannot chdir(@{[ $self->base ]}): $!";
        my $workdir = $self->dir("work-$branch");
        unless (-d $workdir) {
            $self->command("git clone --recursive --branch $self->{branch} @{[ $self->repo ]} $workdir");
        }
        chdir($workdir) or die "Cannot chdir($workdir): $!";
        $self->command("git pull -f origin $branch");
        $self->command("git reset --hard origin/$branch");
        $self->command("git status");

        my $report = $self->run_test();
        if ($report) {
            $self->notify($branch, $report);
            $fail++;
        }
    }

    $self->log("end testing");

    return $fail;
}

sub notify {
    my ($self, $branch, $report) = @_;
    warn "NOTIFY : $branch, $report";
    if (defined $self->ikachan_url) {
        my $url = $self->ikachan_url;
        $url =~ s!/$!!; # remove trailing slash

        my $ua = LWP::UserAgent->new(agent => "Cigar/$VERSION");
		{
			my $res = $ua->post( "$url/join",
				{ channel => $self->ikachan_channel } );
			$res->code =~ /^(?:20.|403)$/ or die join(' ', 'join', $self->ikachan_url, $self->ikachan_channel, $res->status_line);
		}
		{
			my $res = $ua->post( "$url/notice",
				{ channel => $self->ikachan_channel, message => $report } );
			$res->is_success or die join(' ', 'notice', $self->ikachan_url, $self->ikachan_channel, $res->status_line);
		}
    }
}

sub run_test {
    my $self = shift;
    if (-x './bin/test.pl') {
        system('./bin/test.pl')==0 or return "testing failed: $?";
    } else {
        system("perl Makefile.PL")==0 or return "Cannot run Makefile.PL: $!";
        system("make test")==0 or return "make test failed.. $?";
    }
}

sub file {
    my $self = shift;
    File::Spec->catfile($self->base, @_);
}

sub dir {
    my $self = shift;
    File::Spec->catdir($self->base, @_);
}

sub command {
    my $self = shift;
    $self->log("command: @_");
    system(@_)==0 or die "@_: $@";
}

sub log {
    my $self = shift;
    print join(' ', '['.$self->branch.']', @_), "\n";
}

package main;
use Getopt::Long;
use Pod::Usage;

GetOptions(
    'branch=s' => \my $branch,
    'base=s'    => \my $base,
    'repo=s'    => \my $repo,
    'ikachan_url=s' => \my $ikachan_url,
    'ikachan_channel=s' => \my $ikachan_channel,
);
$base or pod2usage();
$repo or pod2usage();
$branch='master' unless $branch;
pod2usage() if $ikachan_url && !$ikachan_channel;

my $app = App::Cigar->new(
    branch          => $branch,
    base            => $base,
    repo            => $repo,
    ikachan_url     => $ikachan_url,
    ikachan_channel => $ikachan_channel
);
exit($app->run());

__END__

=head1 SYNOPSIS

    % cigar.pl --repo=git://... --base /path/to/base/dir
    % cigar.pl --repo=git://... --base /path/to/base/dir --branch foo

        --repo=s    URL for git repository
        --base=s    Base directory for working
        --branch=s  branch name('master' by default)
        --ikachan_url=s API endpoint URL for ikachan
        --ikachan_channel=s channel to post message

=head1 DESCRIPTION

超絶簡易的CIツール。 cron でよしなにぐるぐるまわして、fail したら mail とばす、で OK。

    MAILTO=ci@example.com
    */20 * * * * cronlog --timestamp -- cigar.pl --repo=git://github.com/ikebe/Pickles.git --branch switch_routes --base=/tmp/pickles-ci/

cronlog はこちらからインストールしてください: https://github.com/kazuho/kaztools

=head1 SEE ALSO

https://github.com/yappo/p5-App-Ikachan

