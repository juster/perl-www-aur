#!/usr/bin/perl

use warnings;
use strict;
use Test::More qw(no_plan);

use WWW::AUR::Package;

my $pkg = WWW::AUR::Package->new( 'perl-cpanplus-dist-arch',
                                  basepath => 't/tmp' );
diag "Building perl-cpanplus-dist-arch";
my $builtpath = $pkg->build( quiet => 1 );
ok $builtpath;
is $builtpath, $pkg->bin_pkg_path;
