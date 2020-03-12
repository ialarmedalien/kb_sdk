use PerlTest::PerlTestImpl;

use strict;
use warnings;

use PerlTest::PerlTestServer;
use Plack::Middleware::CrossOrigin;


my @dispatch;

{
    my $obj = PerlTest::PerlTestImpl->new;
    push @dispatch, 'Basic' => $obj;
}

my $server = PerlTest::PerlTestServer->new(
    instance_dispatch   => { @dispatch },
    allow_get           => 0,
);

my $handler = sub { $server->handle_input(@_) };

$handler = Plack::Middleware::CrossOrigin->wrap(
    $handler,
    origins => "*",
    headers => "*"
);
