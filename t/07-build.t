#!/usr/bin/perl

use warnings 'FATAL' => 'all';
use strict;
use Test::More;

BEGIN {
    eval { require IPC::Cmd; 1 }
        or plan 'skip_all' => 'Test needs IPC::Cmd installed';
    IPC::Cmd::can_run( 'makepkg' )
        or plan 'skip_all' => 'Test needs makepkg utility';

    plan 'tests' => 3;
    use_ok 'WWW::AUR::Package';
}

my $pkgname = 'perl-archlinux-term';

my $pkg = WWW::AUR::Package->new( $pkgname, 'basepath' => 't/tmp' );
diag "Test building $pkgname";
my $builtpath = $pkg->build( 'quiet' => 1 );
ok $builtpath;
is $builtpath, $pkg->bin_pkg_path;

done_testing;
