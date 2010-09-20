package WWW::AUR::Var;

use warnings;
use strict;

use parent qw(Exporter);
use Carp   qw();

our @EXPORT = qw($VERSION $BASEPATH $BASEURI $USERAGENT
                 category_index category_name);;

our $VERSION   = '0.01';
our $BASEPATH  = '/tmp/WWW-AUR';
our $BASEURI   = 'http://aur.archlinux.org';
our $USERAGENT = "WWW::AUR/v$VERSION";

my @_CATEGORIES = qw{ daemons devel editors emulators games gnome
                      i18n kde kernels lib modules multimedia
                      network office science system x11 xfce };

#---EXPORT FUNCTION---
sub category_name
{
    my ($idx) = @_;
    Carp::croak "$idx is not a valid category index"
        unless $idx > 0 && $idx <= scalar @_CATEGORIES;

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
