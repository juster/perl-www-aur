#!/usr/bin/perl

use warnings 'FATAL' => 'all';
use strict;
use Test::More tests => 2;

diag 'Iterating through 100 package names';

use WWW::AUR::Iterator;
my $iter = WWW::AUR::Iterator->new;

my ( $i, @found ) = 0;
while ( $i < 100 && ( my $pkgname = $iter->next_name )) {
    push @found, $pkgname;
    ++$i;
}

is scalar @found, 100, 'We iterated through 100 packages';

sub check_pkgobjs
{
    my ($pkgnames_ref) = @_;

    diag q{Iterating through 100 package objects (slower)};

    my $iter = WWW::AUR::Iterator->new;
    while ( @$pkgnames_ref ) {
        my $pkgname = shift @$pkgnames_ref;
        my $pkg     = $iter->next;
        return 0 unless $pkg->name eq $pkgname;
    }
    return 1;
}

ok check_pkgobjs( \@found ), 'Package names and package objects match';
