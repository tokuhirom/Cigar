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
use Time::Piece;
use IPC::Open3;
use English '-no_match_vars';
use File::Basename qw(dirname);

sub base            { $_[0]->{base} }
sub branch          { $_[0]->{branch} }
sub repo            { $_[0]->{repo} }
sub ikachan_url     { $_[0]->{ikachan_url} }
sub ikachan_channel { $_[0]->{ikachan_channel} }
sub viewer_url      { $_[0]->{viewer_url} }

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

    # make log directory first.
    mkpath($self->dir('logs'));

    $self->log("start testing : " . join(' ', $self->repo, $self->branch));

    {
        mkpath($self->base);
        mkpath($self->dir('work'));
        chdir($self->base) or die "Cannot chdir(@{[ $self->base ]}): $!";

        my $workdir = $self->dir("work", $self->branch);
        unless (-d $workdir) {
            $self->command("git clone --branch $self->{branch} @{[ $self->repo ]} $workdir");
        }
        chdir($workdir) or die "Cannot chdir($workdir): $!";
        $self->command("git pull -f origin $branch");
        $self->command("git reset --hard origin/$branch");
        $self->command("git submodule init");
        $self->command("git submodule update");
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

		my $message = $report;
        if ( $self->viewer_url ) {
            $message = join( ' ',
                $self->viewer_url() . '/logs/' . $self->get_logfile_name(),
                "[$self->{branch}]", $message );
        }
        $self->log("Sending message to irc server: $message");

        my $ua = LWP::UserAgent->new(agent => "Cigar/$VERSION");
		my $res = $ua->post( "$url/notice",
			{ channel => $self->ikachan_channel, message => $message } );
		$res->is_success or die join(' ', 'notice', $self->ikachan_url, $self->ikachan_channel, $res->status_line);
    }
}

sub run_test {
    my $self = shift;

    my $logfilepath = $self->file('logs', $self->get_logfile_name());
	$self->log("log file name: $logfilepath");
    if (-x './bin/test.pl') {
        $self->tee("./bin/test.pl 2>&1")==0 or return "test.pl FAIL: $?";
    } else {
        $self->tee("perl Makefile.PL 2>&1")==0 or return "Makefile.PL FAIL: $?";
        $self->tee("make test 2>&1")==0 or return "make test FAIL: $?";
    }
	return undef;
}


sub command {
	my $self = shift;
    $self->log("command: @_");
	system(@_)==0 or die "@_: $!";
}

sub tee {
	my ($self, $command) = @_;
    $self->log("command: $command");
	my $pid = open(my $fh, '-|');
	local $SIG{PIPE} = sub { die "whoops, $command pipe broke" };

    if ($pid) {    # parent
        while (<$fh>) {
            print $_;
			print {$self->logfh} $_;
        }
        close($fh) || warn "kid exited $?";
		return $?;
    }
    else {         # child
        ( $EUID, $EGID ) = ( $UID, $GID );
        exec( $command );
        die "can't exec $command $!";
    }
}

sub logfh {
	my ($self) = @_;
	$self->{logfh} ||= do {
		my $fname = $self->file('logs', $self->get_logfile_name());
        mkpath(dirname($fname));
		open my $fh, '>>', $fname or die "Cannot open $fname: $!";
		$fh;
	};
}

sub get_logfile_name {
	my $self = shift;

    return $self->{logfile_name} ||= File::Spec->catfile(
        $self->branch,
        Time::Piece->new->strftime('%Y%m%d'),
        ( substr( `git rev-parse HEAD`, 0, 10 ) || 'xxx' ) . '-'
          . time() . '.txt'
    );
}

sub file {
    my $self = shift;
    File::Spec->catfile($self->base, @_);
}

sub dir {
    my $self = shift;
    File::Spec->catdir($self->base, @_);
}

sub log {
    my $self = shift;
    my $msg = join( ' ',
        Time::Piece->new()->strftime('[%Y-%m-%d %H:%M]'),
        '[' . $self->branch . ']', @_ )
      . "\n";
	print STDOUT $msg;
	print {$self->logfh} $msg;
}

package main;
use Getopt::Long;
use Pod::Usage;

GetOptions(
    'branch=s'          => \my $branch,
    'base=s'            => \my $base,
    'repo=s'            => \my $repo,
    'ikachan_url=s'     => \my $ikachan_url,
    'ikachan_channel=s' => \my $ikachan_channel,
    'viewer_url=s'      => \my $viewer_url,
);
$base or pod2usage();
$repo or pod2usage();
$branch='master' unless $branch;
die "Bad branch name: $branch" unless $branch =~ /^[A-Za-z0-9._-]+$/; # guard from web
pod2usage() if $ikachan_url && !$ikachan_channel;
$viewer_url =~ s!/$!!;

my $app = App::Cigar->new(
    branch          => $branch,
    base            => $base,
    repo            => $repo,
    ikachan_url     => $ikachan_url,
    ikachan_channel => $ikachan_channel,
	viewer_url      => $viewer_url,
);
exit($app->run());

__END__

=head1 SYNOPSIS

    % cigar.pl --repo=git://... --base /path/to/base/dir
    % cigar.pl --repo=git://... --base /path/to/base/dir --branch foo

        --repo=s            URL for git repository
        --base=s            Base directory for working
        --branch=s          branch name('master' by default)
        --ikachan_url=s     API endpoint URL for ikachan
        --ikachan_channel=s channel to post message
        --viewer_url=s      log viewer url(using app.psgi)

=head1 DESCRIPTION

超絶簡易的CIツール。 cron でよしなにぐるぐるまわして、fail したら mail とばす、で OK。

    MAILTO=ci@example.com
    */20 * * * * cronlog --timestamp -- cigar.pl --repo=git://github.com/ikebe/Pickles.git --branch switch_routes --base=/tmp/pickles-ci/

cronlog はこちらからインストールしてください: https://github.com/kazuho/kaztools

=head1 SEE ALSO

https://github.com/yappo/p5-App-Ikachan

