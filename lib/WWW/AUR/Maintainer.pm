package WWW::AUR::Maintainer;

use warnings;
use strict;

use LWP::UserAgent qw();
use Carp           qw();

use WWW::AUR qw();

#---CONSTRUCTOR---
sub new
{
    my $class = shift;

    my ($name, %params) = @_
        or Carp::croak 'You must supply a maintainer name as argument';

    my $packages = _find_owned_packages( $name, \%params )
        or Carp::croak qq{Could not find a maintainer named "$name"};

    bless { name => $name, packages => $packages }, $class;
}

#---HELPER FUNCTION---
sub _find_owned_packages
{
    my ($name, $params_ref) = @_;

    my $aururl = WWW::AUR::_aur_rpc_url( 'msearch', $name );
    my $ua     = LWP::UserAgent->new( agent => $WWW::AUR::USERAGENT );
    my $resp   = $ua->get( $aururl );

    Carp::croak qq{Failed to lookup maintainer with AUR RPC:\n}
        . $resp->status_code unless $resp->is_success;

    my $json     = JSON->new;
    my $json_ref = $json->decode( $resp->content );

    if ( $json_ref->{type} eq 'error' ) {
        return undef if $json_ref->{results} eq 'No results found';
        Carp::croak "Remote error: $json_ref->{results}";        
    }

    my %pkgparams;
    for my $key ( qw/ basepath dlpath extpath destpath / ) {
        $pkgparams{ $key } = $params_ref->{ $key };
    }

    require WWW::AUR::Package;
    my @packages = map {
        my $info = WWW::AUR::_rpc_pretty_pkginfo( $_ );
        WWW::AUR::Package->new( $info->{name}, info => $info, %pkgparams );
    } @{ $json_ref->{results} };

    return \@packages;
}

#---PUBLIC METHOD---
sub packages
{
    my ($self) = @_;
    return @{ $self->{packages} };
}

1;

__END__
