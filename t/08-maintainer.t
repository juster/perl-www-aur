#!/usr/bin/perl

use warnings 'FATAL' => 'all';
use strict;
use Test::More tests => 4;

use WWW::AUR::Maintainer;

my $who = WWW::AUR::Maintainer->new( 'juster' );
ok $who;

my $found = 0;
for my $pkg ( $who->packages ) {
    if ( $pkg->name eq 'perl-www-aur' ) { $found = 1; }
}
ok $found, 'found perl-www-aur, owned by juster';

my $pkg = WWW::AUR::Package->new( 'perl-alpm' );
ok $pkg, 'looked up perl-alpm package';
my $maintainer = $pkg->maintainer;
ok $maintainer->name eq 'juster', 'perl-alpm is owned by juster';
