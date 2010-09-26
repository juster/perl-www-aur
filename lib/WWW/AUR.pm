package WWW::AUR;

use warnings;
use strict;

use Carp qw();

use WWW::AUR::URI;
use WWW::AUR::Var;
use WWW::AUR::RPC;

our $VERSION = '0.01';

sub new
{
    my $class  = shift;
    my %params = @_;
    $params{ basepath } ||= $BASEPATH;

    return bless \%params, $class
}

sub search
{
    my ($self, $query) = @_;
    my $found_ref = WWW::AUR::RPC::search( $query );

    require WWW::AUR::Package;
    my %params = path_params( %$self );
    return map {
        WWW::AUR::Package->new( $_->{name}, info => $_, %params );
    } @$found_ref;
}

sub _def_wrapper_method
{
    my ($name, $class) = @_;

    no strict 'refs';
    *{ "WWW::AUR::$name" } = sub {
        my $self        = shift;
        my %path_params = path_params( %$self );

        eval "require $class";
        return eval { $class->new( @_, %path_params ) };
    };
}

_def_wrapper_method( 'find'       => 'WWW::AUR::Package'    );
_def_wrapper_method( 'maintainer' => 'WWW::AUR::Maintainer' );
_def_wrapper_method( 'packages'   => 'WWW::AUR::Iterator'   );
_def_wrapper_method( 'login'      => 'WWW::AUR::Login'      );

1;
