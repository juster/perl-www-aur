#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 7;
use File::Spec::Functions qw(rel2abs splitpath catdir);

use WWW::AUR;

my $aur = WWW::AUR->new( basepath => 't/tmp' );
my $pkg = $aur->find( 'perl-cpanplus-dist-arch' );
ok $pkg, 'looked up perl-cpanplus-dist-arch package';

my $download_size = $pkg->download_size();
ok $download_size > 0, 'web download size';

ok my $pkgfile = $pkg->download();
ok -f $pkgfile, 'source package file was downloaded';
ok $download_size == (-s $pkgfile),
    'downloaded file size matches the web reported size';

$pkg = $aur->find( 'perl-archlinux-messages' );
ok $pkg, 'looked up perl-archlinux-messages package';

my $done = 0;
my $cb = sub {
    my ($dl, $total) = @_;
    $done = 1 if $dl == $total;
};
$pkg->download( $cb );
ok $done, 'download callback works';
