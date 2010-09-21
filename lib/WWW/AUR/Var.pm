package WWW::AUR::Var;

use warnings;
use strict;

use parent qw(Exporter);
use Carp   qw();

our @EXPORT = qw($VERSION $BASEPATH $BASEURI $USERAGENT
                 category_index category_name is_path_param path_params);

our $VERSION   = '0.01';
our $BASEPATH  = '/tmp/WWW-AUR';
our $BASEURI   = 'http://aur.archlinux.org';
our $USERAGENT = "WWW::AUR/v$VERSION";

my %_IS_PATH_PARAM = map { ( $_ => 1 ) }
    qw/ basepath dlpath extpath destpath /;
sub is_path_param
{
    my ($name) = @_;
    return $_IS_PATH_PARAM{ $name };
}

sub path_params
{
    my %filterme = @_;
    my %result;
    for my $key ( grep { is_path_param( $_ ) } keys %filterme ) {
        $result{ $key } = $filterme{ $key };
    }
    return %result;
}

my @_CATEGORIES = qw{ daemons devel editors emulators games gnome
                      i18n kde kernels lib modules multimedia
                      network office science system x11 xfce };

#---EXPORT FUNCTION---
sub category_name
{
    my ($idx) = @_;
    return 'undefined' unless $idx > 0 && $idx <= scalar @_CATEGORIES;
    return $_CATEGORIES[ $idx - 1 ];
}

#---EXPORT FUNCTION---
sub category_index
{
    my ($name) = @_;
    $name = lc $name;

    for my $i ( 0 .. $#_CATEGORIES ) {
        return $i if $name eq $_CATEGORIES[ $i ];
    }

    Carp::croak "$name is not a valid category name";
}


1;
