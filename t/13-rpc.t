#!perl

use warnings;
use strict;
use Test::More;

use_ok 'WWW::AUR::RPC';

my %info = WWW::AUR::RPC::info('perl-alpm');
is $info{'name'}, 'perl-alpm';

my @found = WWW::AUR::RPC::search('perl-');
ok scalar @found > 0;

my @infos = WWW::AUR::RPC::multiinfo('perl-alpm', 'perl-www-aur');
@infos = sort { $a->{'name'} cmp $b->{'name'} } @infos;
is $infos[0]{'name'}, 'perl-alpm';
is $infos[1]{'name'}, 'perl-www-aur';

done_testing;
