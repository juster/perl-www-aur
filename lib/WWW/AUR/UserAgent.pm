package WWW::AUR::UserAgent;

use warnings;
use strict;

use parent qw(LWP::UserAgent);
use WWW::AUR;

sub new
{
    my $class = shift;
    $class->SUPER::new( agent => $WWW::AUR::USERAGENT, @_ );
}

1;
