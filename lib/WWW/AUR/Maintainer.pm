package WWW::AUR::Maintainer;

use warnings;
use strict;

use Carp qw();

use WWW::AUR::RPC;

#---CONSTRUCTOR---
sub new
{
    my $class = shift;

    my ($name, %params) = @_
        or Carp::croak 'You must supply a maintainer name as argument';

    my $packages_ref = WWW::AUR::RPC::msearch( $name )
        or Carp::croak qq{Maintainer named "$name" does not exist};

    bless { name => $name, packages => $packages_ref, %params }, $class;
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

    my $pkgs = $self->{packages};

    require WWW::AUR::Package;
    return map { WWW::AUR::Package->new( $_->{name}, info => $_ ) }
        @$pkgs;
}

1;

__END__
