package WWW::AUR;

use warnings;
use strict;

use LWP::Simple qw();
use JSON        qw();
use Carp        qw();

our $VERSION   = '0.01';
our $USERAGENT = "WWW::AUR/v$VERSION";
our $BASEPATH  = '/tmp/WWW-AUR';
our $BASEURI   = 'http://aur.archlinux.org';

my %_IS_AUR_FIELD = map { ( $_ => 1 ) } qw/ basepath buildpath pkgpath /;
sub new
{
    my $class  = shift;
    my %params = @_;

    for my $key ( keys %params ) {
        Carp::croak "Invalid constructor parameter: $key"
            unless $_IS_AUR_FIELD{ $key };
    }

    $params{ basepath } ||= $BASEPATH;

    return bless \%params, $class
}

my %_IS_RPC_METHOD = map { ( $_ => 1 ) } qw/ search info msearch /;
#---HELPER FUNCTION---
sub _aur_rpc_url
{
    my ($method, $arg) = @_;

    Carp::croak( "$method is not a valid AUR RPC method" )
        unless $_IS_RPC_METHOD{ $method };

    return "${BASEURI}/rpc.php?type=${method}&arg=${arg}";
}

my %_RENAME_FOR = ( 'Description' => 'desc',
                    'NumVotes'    => 'votes',
                    'CategoryID'  => 'category',
                    'LocationID'  => 'location',
                    'OutOfDate'   => 'outdated',
                   );
#---HELPER FUNCTION---
sub _aur_rpc_keyname
{
    my ($key) = @_;

    return $_RENAME_FOR{ $key } || lc $key;
}

#---CLASS/OBJECT METHOD---
sub info
{
    my (undef, $name) = @_;

    my $url     = _aur_rpc_url( "info", $name );
    my $jsontxt = LWP::Simple::get( $url );

    Carp::croak "Failed to call info AUR RPC" unless defined $jsontxt;

    my $json = JSON->new;
    my $resp = $json->decode( $jsontxt );

    if ( $resp->{type} eq "error" ) {
        return undef if $resp->{results} eq 'No results found';
        Carp::croak "Remote error: $resp->{results}";
    }

    # Map keys to their new names before we return the results...
    my %result;
    for my $key ( keys %{ $resp->{results} } ) {
        $result{ _aur_rpc_keyname( $key ) } = $resp->{results}{$key};
    }
    return %result;
}

sub search
{
    my (undef, $query) = @_;

    my $regexp;
    if ( $query =~ /\^/ || $query =~ /\$/ ) {
        $regexp = quotemeta $query;
        $query  =~ s/\A^//;
        $query  =~ s/\$\z//;
    }

    my $url     = _aur_rpc_url( "search", $query );
    my $jsontxt = LWP::Simple::get( $url )
        or Carp::croak 'Failed to search AUR using RPC';
    my $json    = JSON->new;
    my $data    = $json->decode( $jsontxt )
        or die 'Failed to decode the search AUR json request';

    my @results;
    if ( $data->{type} eq 'error' ) {
        return [] if $data->{results} eq 'No results found';
        Carp::croak "Remote error: $data->{results}";
    }

    require WWW::AUR::Package;
    @results = map {
        my $info = {};
        for my $key ( keys %$_ ) {
            $info->{ _aur_rpc_keyname( $key ) } = $_->{ $key }; 
        }
        WWW::AUR::Package->new( $info->{name}, info => $info );
    } @{ $data->{results} };
    return \@results;
}

1;

__END__

=head1 NAME

WWW::AUR - API for the Archlinux User Repository website.

=head1 SYNOPSIS

=head1 DESCRIPTION

This module provides an interface for the straight-forward AUR user
as well as an AUR author, or package maintainer.

=head1 AUTHOR

Justin Davis, C<< <juster at cpan dot org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-aur at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-AUR>.  I will be
notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

Read the manual first.  Send me an email if you still need help.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Justin Davis.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
