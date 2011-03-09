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

sub pkgfile_uri
{
    my ($pkgname) = @_;
    return "http://$WWW::AUR::HOST/packages/$pkgname/$pkgname.tar.gz";
}

sub pkgbuild_uri
{
    my ($pkgname) = @_;
    return "http://$WWW::AUR::HOST/packages/$pkgname/PKGBUILD"
}

sub pkg_uri
{
    my %params = @_;
    my $scheme = delete $params{'https'} ? 'https' : 'http';
    my $uri    = URI->new( "$scheme://$WWW::AUR::HOST/packages.php" );
    $uri->query_form([ %params ]);
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

__END__

=head1 NAME

WWW::AUR::URI - Generate dynamic URIs for accessing the AUR

=head1 DESCRIPTION

This is a collection of functions used internally by other modules
in the WWW-AUR distribution. For advanced users only.

=head1 EXPORTS

This module exports nothing by default. You must explicitly import
functions or import the C<all> tag to import all functions.

  use WWW::AUR::URI qw( pkgfile_uri pkgbuild_uri pkg_uri rpc_uri );
  use WWW::AUR::URI qw( :all );

=head1 FUNCTIONS

=head2 pkgfile_uri

  $URI = pkgfile_uri( $PKGNAME )

=over 4

=item C<$PKGNAME>

The name of the package.

=item C<$URI>

The URI to the source package tarball.

=back

=head2 pkgbuild_uri

  $URI = pkgbuild_uri( $PKGNAME )

=over 4

=item C<$PKGNAME>

The name of the package.

=item C<$URI>

The URI to the conveniently extracted PKGBUILD file.

=back

=head2 pkg_uri

  $URI = pkg_uri( %QUERY_PARAMS )

This generates a URI for the L<http://aur.archlinux.org/packages.php>
webpage. The one that shows package information and comments, etc.

=over 4

=item C<%QUERY_PARAMS>

You can supply whatever query parameters that you want. You might want
to look at the AUR's HTML source to learn how they work.

One special parameter that acts differently is the C<'https'>
parameter. If this key exists and its value is a truthy value, then
the URI is given as an I<https> link and not an I<http> link.  The
C<'https'> parameter is also not passed in as a query parameter.

=item C<$URI>

The URI to I<packages.php> with query parameters appended.

=back

=head2 rpc_uri

  $URI = rpc_uri( $METHOD, $ARG )

Generates a URI for the L<http://aur.archlinux.org/rpc.php> page.

=over 4

=item C<$METHOD>

The RPC "method" to use. Possible values include: C<"search">, C<"info">, or
C<"msearch">.

=item C<$ARG>

The RPC "argument" to give to the "method".

=item C<$URI>

The URI to the rpc.php page with query parameters attached.

=back

=head1 SEE ALSO

L<WWW::AUR>

=head1 AUTHOR

Justin Davis, C<< <juster at cpan dot org> >>

=head1 BUGS

Please email me any bugs you find. I will try to fix them as quick as I can.

=head1 SUPPORT

Send me an email if you have any questions or need help.

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Justin Davis.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut


