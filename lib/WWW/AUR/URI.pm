package WWW::AUR::URI;

use warnings;
use strict;

use Carp qw();
use URI  qw();

use WWW::AUR::Var;

use parent qw(Exporter);

our @EXPORT    = qw(pkgfile_uri pkgbuild_uri pkg_uri rpc_uri);

my $PKGURI    = "$BASEURI/packages.php";

sub pkgfile_uri
{
    my ($pkgname) = @_;
    my $uri = URI->new( $BASEURI );
    $uri->path( "/packages/$pkgname/$pkgname.tar.gz" );
    return $uri->as_string;
}

sub pkgbuild_uri
{
    my ($pkgname) = @_;
    my $uri = URI->new( $BASEURI );
    $uri->path( "/packages/$pkgname/$pkgname/PKGBUILD" );
    return $uri->as_string;
}

sub pkg_uri
{
    my (%params) = @_;

    my $uri = URI->new( $PKGURI );
    $uri->query_form( %params );
    return $uri->as_string;
}

my %_IS_RPC_METHOD = map { ( $_ => 1 ) } qw/ search info msearch /;

#---EXPORT FUNCTION---
sub rpc_uri
{
    my ($method, $arg) = @_;

    Carp::croak( "$method is not a valid AUR RPC method" )
        unless $_IS_RPC_METHOD{ $method };

    my $uri = URI->new( "${BASEURI}/rpc.php" );
    $uri->query_form( 'type' => $method, 'arg' => $arg );
    return $uri->as_string;
}

1;

__END__
