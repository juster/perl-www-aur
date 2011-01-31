package WWW::AUR::UserAgent;

use warnings 'FATAL' => 'all';
use strict;

use LWP::UserAgent;
use WWW::AUR;

our @ISA = qw(LWP::UserAgent);

sub new
{
    my $class = shift;
    $class->SUPER::new( agent => $WWW::AUR::USERAGENT, @_ );
}

1;
