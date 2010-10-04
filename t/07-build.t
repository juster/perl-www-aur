#!/usr/bin/perl

use warnings;
use strict;
use Test::More;

BEGIN {
    eval { require IPC::Cmd; 1 }
        or plan 'skip_all' => 'Test need IPC::Cmd installed';
    IPC::Cmd::can_run( 'makepkg' )
        or plan 'skip_all' => 'Test needs makepkg utility';

    plan 'tests' => 3;
    use_ok 'WWW::AUR::Package';
}

my $pkg = WWW::AUR::Package->new( 'perl-cpanplus-dist-arch',
                                  basepath => 't/tmp' );
diag "Building perl-cpanplus-dist-arch";
my $builtpath = $pkg->build( quiet => 1 );
ok $builtpath;
is $builtpath, $pkg->bin_pkg_path;

done_testing;
