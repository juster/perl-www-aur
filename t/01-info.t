#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use WWW::AUR;

my $aur  = WWW::AUR->new;
ok my %info = $aur->info( 'clyde-git' );
is $info{ name }, 'clyde-git';

my @VALID_FIELDS = qw{ id name version category desc url urlpath
                       license votes outdated };

for my $field ( @VALID_FIELDS ) {
    ok exists $info{ $field }, qq{info contains "$field" field};
}

done_testing();
