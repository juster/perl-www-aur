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

    my $results = WWW::AUR::RPC::msearch( $name )
        or return undef;
    
    require WWW::AUR::Package;
    my @packages = map {
        WWW::AUR::Package->new( $_->{name}, info => $_, %$params_ref );
    } @$results;
    return \@packages;
}

sub name
{
    my ($self) = @_;
    return $self->{name};
}

#---PUBLIC METHOD---
sub packages
{
    my ($self) = @_;
    return @{ $self->{packages} };
}

1;

__END__
