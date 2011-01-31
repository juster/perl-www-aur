#!/usr/bin/perl

use warnings 'FATAL' => 'all';
use strict;
use Test::More;

use_ok 'WWW::AUR::RPC';

ok my %info = WWW::AUR::RPC::info( 'clyde-git' );
is $info{ name }, 'clyde-git';

my @VALID_FIELDS = qw{ id name version category desc url urlpath
                       license votes outdated };

for my $field ( @VALID_FIELDS ) {
    ok exists $info{ $field }, qq{info contains "$field" field};
}

is $info{category}, 'system', 'category was converted to its name';

done_testing();
