package WWW::AUR::URI;

use warnings 'FATAL' => 'all';
use strict;

use Carp     qw();
use URI      qw();
use Exporter qw();

use WWW::AUR;

our @ISA    = qw(Exporter);
our @EXPORT = qw(pkgfile_uri pkgbuild_uri pkg_uri rpc_uri);

sub pkgfile_uri
{
    my ($pkgname) = @_;
    return "http://$WWW::AUR::HOST/packages/$pkgname/$pkgname.tar.gz";
}

sub pkgbuild_uri
{
    my ($pkgname) = @_;
    return "http://$WWW::AUR::HOST/packages/$pkgname/$pkgname/PKGBUILD"
}

sub pkg_uri
{
    my %params = @_;
    my $scheme = delete $params{'https'} ? 'https' : 'http';
    my $uri    = URI->new( "$scheme://$WWW::AUR::HOST/packages.php" );
    $uri->query_form([ @_ ]);
    return $uri->as_string;
}

my @_RPC_METHODS = qw/ search info msearch /;

sub rpc_uri
{
    my ($method, $arg) = @_;

    Carp::croak( "$method is not a valid AUR RPC method" )
        unless grep { $_ eq $method } @_RPC_METHODS;

    my $uri = URI->new( "http://$WWW::AUR::HOST/rpc.php" );
    $uri->query_form( 'type' => $method, 'arg' => $arg );
    return $uri->as_string;
}

1;
