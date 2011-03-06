package WWW::AUR;

use warnings 'FATAL' => 'all';
use strict;

use Exporter;
use Carp qw();

BEGIN {
    # We must define these as soon as possible. They are used in other
    # WWW::AUR modules. Like the ones we use after this block...

    our $VERSION   = '0.08';
    our $BASEPATH  = '/tmp/WWW-AUR';
    our $HOST      = 'aur.archlinux.org';
    our $USERAGENT = "WWW::AUR/v${VERSION}";

    our @ISA       = qw(Exporter);
    our @EXPORT_OK = qw(_is_path_param _path_params
                        _category_name _category_index);
}

use WWW::AUR::URI;
use WWW::AUR::RPC;

#---CONSTRUCTOR---
sub new
{
    my $class = shift;
    return bless { _path_params( @_ ) }, $class
}

#---PUBLIC METHOD---
sub search
{
    my ($self, $query) = @_;
    my $found_ref = WWW::AUR::RPC::search( $query );

    require WWW::AUR::Package;
    return map {
        WWW::AUR::Package->new( $_->{name}, info => $_, %$self );
    } @$found_ref;
}

#---HELPER FUNCTION---
sub _def_wrapper_method
{
    my ($name, $class) = @_;

    no strict 'refs';
    *{ "WWW::AUR::$name" } = sub {
        my $self = shift;
        eval "require $class";
        if ( $@ ) {
            Carp::confess "Failed to load $class module:\n$@";
        }
        return eval { $class->new( @_, %$self ) };
    };
}

_def_wrapper_method( 'find'       => 'WWW::AUR::Package'    );
_def_wrapper_method( 'maintainer' => 'WWW::AUR::Maintainer' );
_def_wrapper_method( 'iter'       => 'WWW::AUR::Iterator'   );
_def_wrapper_method( 'login'      => 'WWW::AUR::Login'      );

#-----------------------------------------------------------------------------
# UTILITY FUNCTIONS
#-----------------------------------------------------------------------------
# These functions are used internally by other WWW::AUR modules...

my %_IS_PATH_PARAM = map { ( $_ => 1 ) }
    qw/ basepath dlpath extpath destpath /;

#---INTERNAL FUNCTION---
sub _is_path_param
{
    my ($name) = @_;
    return $_IS_PATH_PARAM{ $name };
}

#---INTERNAL FUNCTION---
sub _path_params
{
    my @filterme = @_;
    my %result;

    FILTER_LOOP:
    while ( my $key = shift @filterme ) {
        next unless _is_path_param( $key );
        my $val = shift @filterme or last FILTER_LOOP;
        $result{ $key } = $val;
    }

    # Fill path parameters with default values if they are unspecified...
    our $BASEPATH;
    my $base = $result{ 'basepath' } || $BASEPATH;
    return ( 'dlpath'   => File::Spec->catdir( $base, 'src'   ),
             'extpath'  => File::Spec->catdir( $base, 'build' ),
             'destpath' => File::Spec->catdir( $base, 'cache' ),
             %result );
}

my @_CATEGORIES = qw{ daemons devel editors emulators games gnome
                      i18n kde kernels lib modules multimedia
                      network office science system x11 xfce };

#---INTERNAL FUNCTION---
sub _category_name
{
    my ($idx) = @_;
    return 'undefined' unless $idx > 0 && $idx <= scalar @_CATEGORIES;
    return $_CATEGORIES[ $idx - 1 ];
}

#---INTERNAL FUNCTION---
sub _category_index
{
    my ($name) = @_;
    $name = lc $name;

    for my $i ( 0 .. $#_CATEGORIES ) {
        return $i if $name eq $_CATEGORIES[ $i ];
    }

    Carp::croak "$name is not a valid category name";
}


1;
