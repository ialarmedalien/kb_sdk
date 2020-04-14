package Bio::KBase::JSONRPCClient;
use strict;
use warnings;
use parent 'JSON::RPC::Client';
use Carp qw( croak );
use Ref::Util qw( is_hashref );
use JSON::MaybeXS;
use LWP::UserAgent;
use Bio::KBase::Logger qw( get_logger );

#
# Override JSON::RPC::Client::call because it doesn't handle error returns properly.
#

sub new {
    my $proto = shift;
    my $self  = bless {}, ( ref $proto ? ref $proto : $proto );

    my $ua  = LWP::UserAgent->new(
        agent   => 'JSON::RPC::Client/' . $JSON::RPC::Client::VERSION . ' beta ',
        timeout => 10,
    );

    my $logger = get_logger();

    $ua->add_handler( request_prepare => sub {
        my $request = shift;

        $logger->debug( message => {
            event   => 'JSONRPC_request_send',
            request => {
                method  => $request->method,
                uri     => $request->uri,
                headers => { $request->headers->flatten },
                content => $request->content,
            }
        } );
    } );

    $ua->add_handler( response_done => sub {
        my $response = shift;

        $logger->debug( message => {
            event       => 'JSONRPC_response_done',
            response    => {
                code    => $response->code,
                headers => { $response->headers->flatten },
            },
        } );
        $logger->trace( content => $response->decoded_content ) if $logger->is_trace;
    } );

    $self->ua( $ua );
    $self->json( $proto->create_json_coder );
    $self->version( '1.1' );
    $self->content_type( 'application/json' );

    return $self;
}

sub call {
    my ( $self, $uri, $headers, $obj ) = @_;

    my $response;

    if ( $uri =~ /\?/ ) {
        $response = $self->_get( $uri );
    }
    else {
        croak "object is not a hashref; it is a " . ( ref( $obj ) || 'SCALAR' )
            unless is_hashref $obj;
        $response = $self->_post( $uri, $headers, $obj );
    }

    my $service = $obj->{ method } =~ /^system\./ if ( $obj );

    $self->status_line( $response->status_line );

    if ( $response->is_success ) {

        return unless $response->content; # notification?

        return JSON::RPC::ServiceObject->new( $response, $self->json ) if $service;
    }

    return JSON::RPC::ReturnObject->new( $response, $self->json )
        if $response->content_type eq 'application/json';

    return;

}

sub _post {
    my ( $self, $uri, $headers, $obj ) = @_;
    my $json = $self->json;

    $obj->{ version } ||= $self->{ version } || '1.1';

    if ( $obj->{ version } eq '1.0') {
        delete $obj->{ version };
        if ( exists $obj->{ id } ) {
            $self->id( $obj->{ id } ) if $obj->{ id }; # if undef, it is notification.
        }
        else {
            $obj->{ id } = $self->id || ( $self->id( 'JSON::RPC::Client' ) );
        }
    }
    else {
        # Assign a random number to the id if one hasn't been set
        $obj->{ id } = $self->id // substr( rand(), 2 );
    }

    my $content = $json->encode( $obj );

    $self->ua->post(
        $uri,
        Content_Type   => $self->{ content_type },
        Content        => $content,
        Accept         => 'application/json',
        @$headers,
        ( $self->{token} ? ( Authorization => $self->{token} ) : () ),
    );
}

1;