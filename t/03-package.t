#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 2;

use WWW::AUR::Package;

eval { WWW::AUR::Package->new( q{this-package-doesn't-exist} ); };
like $@, qr/Failed to find package/;

my $pkg = WWW::AUR::Package->new( 'perl-cpanplus-dist-arch' );
ok $pkg;
