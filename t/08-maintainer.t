#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 4;

use WWW::AUR::Maintainer;

my $who = WWW::AUR::Maintainer->new( 'juster' );
ok $who;

my $found = 0;
for my $pkg ( $who->packages ) {
    if ( $pkg->name eq 'perl-cpanplus-dist-arch' ) { $found = 1; }
}
ok $found, 'found perl-cpanplus-dist-arch, owned by juster';

my $pkg = WWW::AUR::Package->new( 'perl-alpm' );
ok $pkg;
my $maintainer = $pkg->maintainer;
ok $maintainer->name eq 'juster';
