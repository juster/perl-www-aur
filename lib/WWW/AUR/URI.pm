package WWW::AUR::URI;

use warnings 'FATAL' => 'all';
use strict;

use Carp     qw();
use URI      qw();
use Exporter qw();

use WWW::AUR qw(); # for global variables

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(pkgfile_uri pkgbuild_uri pkg_uri rpc_uri);
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );
our $Scheme      = 'http';

sub _pkgdir
{
    my ($pkgname) = @_;
    my $pre = substr $pkgname, 0, 2;
    return "packages/$pre/$pkgname";
}

sub pkgfile_uri
{
    my ($pkgname) = @_;
    my $dir = _pkgdir($pkgname);
    return "$Scheme://$WWW::AUR::HOST/$dir/$pkgname.tar.gz";
}

sub pkgbuild_uri
{
    my ($pkgname) = @_;
    my $dir = _pkgdir($pkgname);
    return "$Scheme://$WWW::AUR::HOST/$dir/PKGBUILD"
}

sub pkg_uri
{
    my %params = @_;
    my $scheme = delete $params{'https'} ? 'https' : 'http';
    $scheme  ||= $Scheme;
    my $uri    = URI->new( "$scheme://$WWW::AUR::HOST/packages.php" );
    $uri->query_form([ %params ]);
    return $uri->as_string;
}

my @_RPC_METHODS = qw/ search info multiinfo msearch /;

sub rpc_uri
{
    my $method = shift;

    Carp::croak( "$method is not a valid AUR RPC method" )
        unless grep { $_ eq $method } @_RPC_METHODS;

    my $uri = URI->new( "$Scheme://$WWW::AUR::HOST/rpc.php" );

    my @qparms = ( 'type' => $method );
    if ($method eq 'multiinfo') {
        push @qparms, map { ( 'arg[]' => $_ ) } @_;
    }
    else {
        push @qparms, ( 'arg' => shift );
    }

    $uri->query_form( \@qparms );
    return $uri->as_string;
}

1;
