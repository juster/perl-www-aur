package WWW::AUR::UserAgent;

use warnings;
use strict;

use WWW::AUR::Var;
use parent qw(LWP::UserAgent);

sub new
{
    my $class = shift;
    $class->SUPER::new( agent => $USERAGENT, @_ );
}

1;
