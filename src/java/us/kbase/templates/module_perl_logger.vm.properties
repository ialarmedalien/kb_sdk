package Bio::KBase::Logger;

use strict;
use warnings;
use Exporter 'import';
use Log::Log4perl;

our @EXPORT_OK = qw( get_logger );

Log::Log4perl->wrapper_register( __PACKAGE__ );

# Log::Log4perl->init_once( 'log4perl.conf' );

sub get_logger { Log::Log4perl->get_logger( @_ ) }

1;
