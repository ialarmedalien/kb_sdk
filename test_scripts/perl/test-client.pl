#
# Automatic test rig for KBase perl client generation.
#
#
#
#
use strict;
use warnings;

use JSON;
use Data::Dumper;
use Test::Most;
use Getopt::Long;
use Path::Tiny;

my $DESCRIPTION = "
USAGE
      perl test-client.pl [options]

DESCRIPTION
      Conducts an automatic test of a perl client against the specified endpoint using
      methods and parameters indicated in the tests config file.

      --tests [filename]    config file for tests
      --endpoint [url]      endpoint of the server to test
      --token [token]       token for testing authenticated calls
      --asyncchecktime [ms] time client waits every cycle of checking state of async methods
      -h, --help            display this help message, ignore all arguments
";

# first parse options to get the testconfig file
my $tests_filename;
my $verbose;
my $endpoint;

my $token;
my $async_job_check_time_ms;

my $help;

my $opt = GetOptions(
    "tests=s"          => \$tests_filename,
    "verbose|v"        => \$verbose,
    "endpoint=s"       => \$endpoint,
    "token=s"          => \$token,
    "asyncchecktime=i" => \$async_job_check_time_ms,
    "help|h"           => \$help,
);

if ( $help ) {
    print $DESCRIPTION. "\n";
    exit 0;
}

# endpoint must be defined
fail_tests( "endpoint parameter must be defined" ) unless $endpoint;

# tests must be defined
fail_tests( "tests parameter must be defined" ) unless $tests_filename;

#parse the tests
my $test_json = parse_test_file( $tests_filename );

my $tests         = $tests_json->{ tests };
my $client_module = $tests_json->{ package };


fail_tests( "tests array not defined in test config file" ) unless $tests && @$tests;

fail_tests( "client module not defined in test config file" ) unless $client_module;

# make sure we can import the module
my $json = JSON->new->canonical;
use_ok( $client_module );

#instantiate an authenticated client and a nonauthenticated client
my $nonauthenticated_client = $client_module->new( $endpoint, ignore_kbase_config => 1 );
ok( defined( $nonauthenticated_client ), "instantiating nonauthenticated client" );

my $authenticated_client;
if ( $token ) {
    if ( $async_job_check_time_ms ) {
        $authenticated_client = $client_module->new(
            $endpoint,
            token                   => $token,
            async_job_check_time_ms => $async_job_check_time_ms
        );
    }
    else {
        $authenticated_client = $client_module->new( $endpoint, token => $token );
    }
    ok( defined( $authenticated_client ), "instantiating authenticated client" );
}

# loop over each test case and run it against the server.  We create a new client instance
# for each test
foreach my $test ( @$tests ) {
    my $client;
    if ( $test->{ 'auth' } ) {

        unless ( $authenticated_client ) {
            fail( "authenticated call declared, but no user and password set" );
            done_testing();
            exit 1;
        }
        $client = $authenticated_client;

    }
    else {
        $client = $nonauthenticated_client;
    }
    ok( defined( $client ), "instantiating client" );

    my $method  = $test->{ method };
    my $params  = $test->{ params };
    my $outcome = $test->{ outcome };
    my $useScalarContext;

    if ( $test->{ context } && $test->{ context } eq 'scalar' ) {
        $useScalarContext = 1;
    }

    ok( $client->can( $method ),
        ' ----------------- method "' . $method . '" exists ------------------------' );

    if ( $client->can( $method ) ) {
        my ( @result, $scalarResult, $failed );
        {
            no strict "refs";
            eval {
                if ( $useScalarContext ) {
                    $scalarResult = $client->$method( @{ $params } );
                }
                else {
                    @result = $client->$method( @{ $params } );
                }
            };
            if ( $@ ) {
                $failed = 1;
                if ( $outcome->{ status } eq 'fail' ) {
                    pass( 'expected failure, and yes it failed' );
                }
                else {
                    fail( 'did not expect to fail, but it did' );
                    print STDERR
                        "Failing test of '$method', expected to pass but error thrown:\n";
                    print STDERR $@->{ message } . "\n";
                    if ( defined( $@->{ status_line } ) ) {
                        print STDERR $@->{ status_line } . "\n";
                    }
                }

                # check that the error message contains the right message
                if ( $outcome->{ error } ) {
                    my $returnedErrorMsg = $@->{ message };
                    foreach my $e ( @{ $outcome->{ error } } ) {
                        if ( index( $returnedErrorMsg, $e ) != -1 ) {
                            pass( "returned error message contains $e" );
                        }
                        else {
                            fail( "returned error message did not contain $e" );
                            print STDERR
                                "Failing test of '$method', expected error to contain message, but it didn't:\n";
                            print STDERR "  looking for: '$e'\n";
                            print STDERR "  got: '$returnedErrorMsg'\n";
                        }
                    }
                }

                # could do more checks here for different failure modes

            }
        }
        if ( $outcome->{ status } eq 'pass' ) {
            pass( 'expected to run successfully, and it did' );
            my ( $serialized_params, $serialized_result );
            if ( $useScalarContext ) {
                $serialized_params = $json->encode( [ @{ $params }[ 0 ] ] );
                $serialized_result = $json->encode( [ $scalarResult ] );
            }
            else {
                $serialized_params = $json->encode( $params );
                $serialized_result = $json->encode( \@result );
            }

            ok(
                $serialized_params eq $serialized_result,
                "response matches input parameters"
            );

            if ( $serialized_params ne $serialized_result ) {
                print STDERR
                    "Failing test of '$method', expected input to match output, but they don't match:\n";
                print STDERR "  in:  " . $serialized_params . "\n";
                print STDERR "  out: " . $serialized_result . "\n";
                print STDERR "\n";
            }
        }
        elsif ( $outcome->{ status } eq 'nomatch' ) {
            pass( 'expected to run successfully, and it did' );
            my ( $serialized_params, $serialized_result );
            if ( $useScalarContext ) {
                ok( $scalarResult, "recieved a response in scalar context" );
                $serialized_params = $json->encode( [ @{ $params }[ 0 ] ] );
                $serialized_result = $json->encode( [ $scalarResult ] );
            }
            else {
                ok( @result, "recieved a response in array context" );
                $serialized_params = $json->encode( $params );
                $serialized_result = $json->encode( \@result );
            }

            ok(
                $serialized_params ne $serialized_result,
                "response does NOT match input parameters"
            );

            if ( $serialized_params eq $serialized_result ) {
                print STDERR
                    "Failing test of '$method', expected input to NOT match output, but they did match:\n";
                print STDERR "  in/out:  " . $serialized_params . "\n";
                print STDERR "\n";
            }
        }
        elsif ( $outcome->{ status } eq 'fail' ) {
            fail( 'expected to fail, but it ran successfully' ) unless $failed;
        }
        else {
            fail(     'expected outcome set to "'
                    . $outcome->{ status }
                    . '", but that is not recognized.  Outcome can only be: pass | fail | nomatch'
            );
        }
    }
}

done_testing();

sub parse_test_file {
    my ( $tests_filename ) = @_;

    my $file_contents = path( $tests_filename )->slurp_utf8;
    return JSON->new->decode( $file_contents );

# open( my $fh, "<", $tests_filename );
# my $tests_string = '';
# while ( my $line = <$fh> ) {
#     chomp $line;
#     $tests_string .= $line;
# }
# close( $fh );
# my $tests_json = JSON->new->decode( $tests_string );

}

sub fail_tests {
    my ( $reason ) = @_;

    fail $reason;
    done_testing();
    exit 1;
}
