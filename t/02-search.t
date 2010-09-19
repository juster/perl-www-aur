#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use WWW::AUR;

my $aur   = WWW::AUR->new;
my $found = $aur->search( 'perl' );

is ref $found, 'ARRAY', 'search results returned an arrayref';
ok @$found > 0, 'more than one perl package was found on the AUR';

my @VALID_FIELDS = qw{ id name version category desc url urlpath
                       license votes outdated };

my $pkg = $found->[0];
ok ref $pkg eq 'WWW::AUR::Package';
for my $field ( @VALID_FIELDS ) {
    ok exists $pkg->{ $field }, qq{package contains "$field" field};
}

done_testing();
