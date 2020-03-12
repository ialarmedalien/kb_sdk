use Test::Most;

subtest 'initialisation' => sub {

    # $class, $url, @args

    my %original_env = %ENV;


    my ( $class, $url, @args ) = @_;

#if( $default_service_url )
    $url //= '${default_service_url}';
#end
    my $self = {
        client  => ${client_package_name}::RpcClient->new,
        url     => $url,
        headers => [],
    };


#     chomp( $self->{ hostname } = `hostname` );
#     $self->{ hostname } ||= 'unknown-host';



    # hardcoded
    my %defaults = {
        async_job_check_time                => 0.1,
        async_job_check_time_scale_percent  => 150,
        async_job_check_max_time            => 300,
        ua_timeout                          => 1800,
    };

    cmp_ok $client->{ async_job_check_time },
        '==',
        $defaults{ async_job_check_time },
        'async job check time ok';

    cmp_ok $client->{ async_job_check_time_scale_percent },
        '==',
        $defaults{ async_job_check_time_scale_percent },
        'async job check time ok';

    cmp_ok $client->{ async_job_check_max_time },
        '==',
        $defaults{ async_job_check_max_time  },
        'async job check time ok';

    isa_ok $client->{ client }, '${client_package_name}::RpcClient';
    is $client->{ url }, 'SOMETHING', 'url ok';

#    is $client->{ service_version },
#        $new_args{ service_version },
#        'service_version OK';

    # timeout
    cmp_ok $client->{ client }->ua->timeout,
        '==',
        $defaults{ ua_timeout },
        'default client timeout is 1800';



    # default state, no env vars: only kbrpc_tag is set
    like $client->{ kbrpc_tag },
        qr/C:.*?:HOSTNAME:$$:\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z/,
        'kbprc tag looks as expected;'

#     is $client->{ kbrpc_metadata }, undef, 'metadata is undef';
#     is $client->{ kbrpc_error_dest }, undef, 'error dest is undef';

    cmp_deeply
        $client->{ headers },
        [ 'Kbrpc-Tag', $client->{ kbrpc_tag } ],
        'headers with no env var set';

    ## NON-DEFAULTS!

    # ASYNC only
    my %new_args    = (
        async_job_check_time_ms             => 50,
        async_job_check_max_time_ms         => 3000,
        async_job_check_time_scale_percent  => 750,
        service_version                     => 'The best one',
        token                               => 'this_is_my_auth_token',
    );

    my $new_url     = 'http://www.example.com';
    my $new_class   = 'Whatever';

    # non-standard
    local $ENV{ KBRPC_TAG }         = 'ALCHEMY';
    local $ENV{ KBRPC_METADATA }    = 'Nanoparticles are cool!';
    local $ENV{ KBRPC_ERROR_DEST }  = '/dev/null';
    # timeout
    local $ENV{ CDMI_TIMEOUT }      = 666;

    my $new_client = ${client_package_name}->new( $new_class, $new_url, @new_args );

    isa_ok $new_client->{ client }, '${client_package_name}::RpcClient';
    is $new_client->{ url }, $new_url, 'url ok';

    # ASYNC only
    cmp_ok $new_client->{ async_job_check_time },
        '==',
        0.05,
        'async job check time set from new_args ok';

    cmp_ok $new_client->{ async_job_check_max_time },
        '==',
        3.0,
        'async job check time max time set from new_args ok';

    is $new_client->{ async_job_check_time_scale_percent },
        $new_args{ async_job_check_time_scale_percent },
        'async job check time scale percent set from new_args ok';

    is $new_client->{ service_version },
        $new_args{ service_version },
        'service_version set from new_args OK';

    is $new_client->{ kbrpc_tag }, 'ALCHEMY', 'tag set from env vars ok';
    is $new_client->{ kbrpc_metadata }, 'Nanoparticles are cool!', 'metadata set from env vars ok';
    is $new_client->{ kbrpc_error_dest }, '/dev/null', 'error dest set from env vars ok';

    cmp_deeply
        $new_client->{ headers },
        [   'Kbrpc-Tag', $new_client->{ kbrpc_tag },
            'Kbrpc-Metadata', $new_client->{ kbrpc_metadata },
            'Kbrpc-Errordest', $new_client->{ kbrpc_error_dest },
        ],
        'headers are correctly set from env vars';

    cmp_ok $new_client->{ client }->ua->timeout,
        '==',
        666,
        'Timeout set from env vars ok';

    # AUTH
    is $new_client->{ token },
        $new_args{ token },
        'token set from new_args ok';

    is  $new_client->{ client }{ token },
        $new_client->{ token },
        'client token ok';
#end




    # headers

#     Set up for propagating KBRPC_TAG and KBRPC_METADATA environment variables through
#     to invoked services. If these values are not set, we create a new tag
#     and a metadata field with basic information about the invoking script.
#
#     if ( $ENV${empty_escaper}{ KBRPC_TAG } ) {
#         $self->{ kbrpc_tag } = $ENV${empty_escaper}{ KBRPC_TAG };
#     }
#     else {
#         my ( $t, $us )       = &$get_time();
#         $us                  = sprintf( "%06d", $us );
#         my $ts               = strftime( "%Y-%m-%dT%H:%M:%S.${us}Z", gmtime $t );
#         $self->{ kbrpc_tag } = "C:$0:$self->{hostname}:$$:$ts";
#     }





#if( $authenticated )
    #
    # This module requires authentication.
    #
    # We create an auth token, passing through the arguments that we were (hopefully) given.
    if ( exists $arg_hash{ token } ) {
        $self->{ token } = $arg_hash{ token };
    }
    elsif ( exists $arg_hash{ user_id } ) {
        my $token = Bio::KBase::AuthToken->new( @args );
        $self->{ token } = $token->token unless $token->error_message;
    }

    $self->{ client }{ token } = $self->{ token } if $self->{ token };
#end




};

subtest '_validate_version' => sub {



    my ($self) = @_;
    my $server_version = $self->version();
    my $client_version = $VERSION;
    my ( $client_major, $client_minor ) = split(/\./, $client_version);
    my ( $server_major, $server_minor ) = split(/\./, $server_version);

    if ( $server_major != $client_major ) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error           => "Major version numbers differ.",
            server_version  => $server_version,
            client_version  => $client_version
        );
    }

    if ( $server_minor < $client_minor ) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error           => "Client minor version greater than server minor version.",
            server_version  => $server_version,
            client_version  => $client_version
        );
    }

    if ( $server_minor > $client_minor ) {
        warn "New client version available for ${client_package_name}\n";
    }

    if ( $server_major == 0 ) {
        warn "${client_package_name} version is $server_version. API subject to change.\n";
    }
};

subtest 'get_service_status' => {
    my ( $self, $module_name ) = @_;

    return $self->_client_call(
        'ServiceWizard.get_service_status',
        $self->{ url },
        $self->{ headers },
        {
            method => "ServiceWizard.get_service_status",
            params => [ {
                module_name => $module_name,
                version     => $self->{ service_version }
            } ]
        }
    );
};

subtest '_client_call' => {
    my ( $self, $method, @call_args ) = @_;

    my $result = $self->{ client }->call( @call_args );

    Bio::KBase::Exceptions::HTTP->throw(
        error       => "Error invoking method $method",
        status_line => $self->{ client }->status_line,
        method_name => $method,
    ) unless $result;

    Bio::KBase::Exceptions::JSONRPC->throw(
        error       => $result->error_message,
        code        => $result->content->{ error }{ code },
        method_name => $method,
        # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
        data        => $result->content->{ error }{ error }
    ) if $result->is_error;

    return $result;
};

subtest '_async_job_check' => sub {
    my ( $self, $job_id ) = @_;
    my $async_job_check_time = $self->{ async_job_check_time };

    while ( 1 ) {
        Time::HiRes::sleep( $async_job_check_time );

        $async_job_check_time *= $self->{ async_job_check_time_scale_percent } / 100.0;
        if ( $async_job_check_time > $self->{ async_job_check_max_time } ) {
            $async_job_check_time = $self->{ async_job_check_max_time };
        }

        my $job_state_ref = $self->_check_job( $job_id );

        if ( $job_state_ref->{ finished } != 0 ) {
            $job_state_ref->{ result } //= [];

            return wantarray
                ? @{ $job_state_ref->{ result } }
                : $job_state_ref->{ result }->[ 0 ];
        }
    }
};

done_testing();

