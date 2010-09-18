#!/usr/bin/perl

use warnings;
use strict;
use Test::More qw(no_plan);

use WWW::AUR::Package;

sub pbtext_ok
{
    my ($pbtext, $expect_ref, $test_name) = @_;

    my %parsed = WWW::AUR::Package::_pkgbuild_fields( $pbtext );
    is_deeply( \%parsed, $expect_ref, $test_name );
    return;
}

my $pbtext = <<'END_PKGBUILD';
pkgname='perl-cpanplus-dist-arch-git'
pkgver='20100530'
pkgrel='1'
pkgdesc='Developer release for CPANPLUS::Dist::Arch perl module'
arch=('any')
license=('PerlArtistic' 'GPL')
options=('!emptydirs')
makedepends=('perl-test-pod-coverage' 'perl-test-pod')
depends=('perl')
provides=('perl-cpanplus-dist-arch')
url='http://github.com/juster/perl-cpanplus-dist-arch'
md5sums=()
source=()
END_PKGBUILD

pbtext_ok( $pbtext,
           { 'pkgname'  => 'perl-cpanplus-dist-arch-git',
             'pkgver'   => '20100530',
             'pkgrel'   => '1',
             'pkgdesc'  => ( 'Developer release for CPANPLUS::Dist::Arch '
                             . 'perl module' ),
             'arch'     => [ 'any' ],
             'license'  => [ 'PerlArtistic', 'GPL' ],
             'options'  => [ '!emptydirs' ],
             'makedepends' => [ 'perl-test-pod-coverage',
                                'perl-test-pod' ],
             'depends'  => [ 'perl' ],
             'provides' => [ 'perl-cpanplus-dist-arch' ],
             'url'      => 'http://github.com/juster/perl-cpanplus-dist-arch',
             'md5sums'  => [],
             'source'   => [] },
           'perl-cpanplus-dist-arch-git PKGBUILD parses' );
