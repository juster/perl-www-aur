#!/usr/bin/perl

use warnings 'FATAL' => 'all';
use strict;
use Test::More tests => 7;
use File::Spec::Functions qw(rel2abs splitpath catdir);

use WWW::AUR;

my $aur = WWW::AUR->new( basepath => 't/tmp' );
my $pkg = $aur->find( 'perl-www-aur' );
ok $pkg, 'looked up perl-www-aur package';

exit 1 unless $pkg;

#my $download_size = $pkg->download_size();
#ok $download_size > 0, 'web download size';

ok my $pkgfile = $pkg->download();
ok -f $pkgfile, 'source package file was downloaded';
ok -s $pkgfile > 0,
    'downloaded file size matches the web reported size';

$pkg = $aur->find( 'perl-archlinux-term' );
ok $pkg, 'looked up perl-archlinux-term package';

my $done = 0;
my $cb = sub {
    my ($dl, $total) = @_;
    $done = 1 if $dl == $total;
};
$pkg->download( $cb );
ok $done, 'download callback works';
