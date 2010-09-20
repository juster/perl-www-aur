package WWW::AUR::RPC;

use warnings;
use strict;

use LWP::UserAgent qw();
use LWP::Simple    qw();
use JSON           qw();
use Carp           qw();

use WWW::AUR::URI;
use WWW::AUR::Var;

my %_RENAME_FOR = ( 'Description' => 'desc',
                    'NumVotes'    => 'votes',
                    'CategoryID'  => 'category',
                    'LocationID'  => 'location',
                    'OutOfDate'   => 'outdated',
                   );

#---HELPER FUNCTION---
# Purpose: Map JSON package info keys to their new names...
sub _rpc_pretty_pkginfo
{
    my ($info_ref) = @_;

    my %result;
    for my $key ( keys %$info_ref ) {
        my $newkey         = $_RENAME_FOR{ $key } || lc $key;
        $result{ $newkey } = $info_ref->{ $key };
    }

    $result{category} = category_name( $result{category} );

    return \%result;
}

#---CLASS/OBJECT METHOD---
sub info
{
    my ($name) = @_;

    my $uri     = rpc_uri( "info", $name );
    my $jsontxt = LWP::Simple::get( $uri );

    Carp::croak "Failed to call info AUR RPC" unless defined $jsontxt;

    my $json = JSON->new;
    my $resp = $json->decode( $jsontxt );

    if ( $resp->{type} eq "error" ) {
        return undef if $resp->{results} eq 'No results found';
        Carp::croak "Remote error: $resp->{results}";
    }

    return %{ _rpc_pretty_pkginfo( $resp->{results} ) };
}

sub search
{
    my ($query) = @_;

    my $regexp;
    if ( $query =~ /\^/ || $query =~ /\$/ ) {
        $regexp = quotemeta $query;
        $query  =~ s/\A^//;
        $query  =~ s/\$\z//;
    }

    my $uri     = rpc_uri( "search", $query );
    my $jsontxt = LWP::Simple::get( $uri )
        or Carp::croak 'Failed to search AUR using RPC';
    my $json    = JSON->new;
    my $data    = $json->decode( $jsontxt )
        or die 'Failed to decode the search AUR json request';

    if ( $data->{type} eq 'error' ) {
        return [] if $data->{results} eq 'No results found';
        Carp::croak "Remote error: $data->{results}";
    }

    return [ map { _rpc_pretty_pkginfo( $_ ) } @{ $data->{results} } ];
}

sub msearch
{
    my ($name) = @_;

    my $aururi = rpc_uri( 'msearch', $name );
    my $ua     = LWP::UserAgent->new( agent => $USERAGENT );
    my $resp   = $ua->get( $aururi );

    Carp::croak qq{Failed to lookup maintainer with AUR RPC:\n}
        . $resp->status_code unless $resp->is_success;

    my $json     = JSON->new;
    my $json_ref = $json->decode( $resp->content );

    if ( $json_ref->{type} eq 'error' ) {
        return undef if $json_ref->{results} eq 'No results found';
        Carp::croak "Remote error: $json_ref->{results}";        
    }

    return [ map { _rpc_pretty_pkginfo( $_ ) } @{ $json_ref->{results} } ];
}

1;
