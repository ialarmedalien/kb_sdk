#
# Automatic test rig for KBase perl client generation.
#
use strict;
use warnings;

use JSON;
use Test::More;
use Data::Dumper;
use Getopt::Long;
use Try::Tiny;

my $DESCRIPTION = "
USAGE
      perl test-client.pl [options]

DESCRIPTION
      Conducts an automatic test of a perl client against the specified endpoint using
      methods and parameters indicated in the tests config file.

      --endpoint [url]      endpoint of the server to test
      --token [token]       token for testing authenticated calls
      --asyncchecktime [ms] time client waits every cycle of checking state of async methods
      --package [package]   package with client module
      --method [method]     method to run
      --input [filename]    input file with parameters in JSON
      --output [filename]   output file with results in JSON
      --error [filename]    output file with text error message
      -h, --help            display this help message, ignore all arguments
";

# first parse options to get the testconfig file
my $verbose;
my $endpoint;

my $token;
my $async_job_check_time_ms;
my $client_module;
my $method;
my $input_filename;
my $output_filename;
my $error_filename;

my $help;

my $opt = GetOptions(
    "verbose|v"        => \$verbose,
    "endpoint=s"       => \$endpoint,
    "token=s"          => \$token,
    "asyncchecktime=i" => \$async_job_check_time_ms,
    "help|h"           => \$help,
    "package=s"        => \$client_module,
    "method=s"         => \$method,
    "input=s"          => \$input_filename,
    "output=s"         => \$output_filename,
    "error=s"          => \$error_filename,
);

if ( $help ) {
    print $DESCRIPTION. "\n";
    exit 0;
}

# endpoint must be defined
unless ( $endpoint ) {
    fail( "endpoint parameter must be defined" );
    exit 1;
}

# package must be defined
unless ( $client_module ) {
    fail( "package parameter must be defined" );
    exit 1;
}

# method must be defined
unless ( $method ) {
    fail( "method parameter must be defined" );
    exit 1;
}

# input must be defined
unless ( $input_filename ) {
    fail( "input parameter must be defined" );
    exit 1;
}

# output must be defined
unless ( $output_filename ) {
    fail( "output parameter must be defined" );
    exit 1;
}

# error must be defined
unless ( $error_filename ) {
    fail( "error parameter must be defined" );
    exit 1;
}

#parse the tests
open( my $fh, "<", $input_filename );
my $input_string = '';
while ( my $line = <$fh> ) {
    chomp $line;
    $input_string .= $line;
}
close( $fh );

my $params  = JSON->new->decode( $input_string );
my $json    = JSON->new->canonical;

eval( "use $client_module;" );

#instantiate an authenticated client and a nonauthenticated client
my %client_args;

if ( $token ) {
    $client_args{ token } = $token;
    $client_args{ async_job_check_time_ms } = $async_job_check_time_ms
        if $async_job_check_time_ms;
}
else {
    $client_args{ ignore_kbase_config } = 1;
}

my $client = $client_module->new( $endpoint, %client_args );

# loop over each test case and run it against the server.  We create a new client instance
# for each test

my @result;
{
    no strict "refs";

    my $error;
    try {
        @result = $client->$method( @{ $params } );
    }
    catch {
        $error = $_;
    };

    my ( $outfile, $data );

    if ( $error ) {
        warn "Caught error: $error";
        open $outfile, '>>', $error_filename;
        $data = "$error";
    }
    else {
        open $outfile, '>>', $output_filename;
        my $data = $json->encode( \@result );
    }

    print { $outfile } $data;

}


