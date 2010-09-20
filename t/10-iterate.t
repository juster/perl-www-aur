#!/usr/bin/perl

use warnings;
use strict;
use Test::More qw(no_plan);

use WWW::AUR::Iterator;

my $iter = WWW::AUR::Iterator->new;

my ( $i, @found ) = 0;
while ( $i < 200 && ( my $pkgname = $iter->next_name )) {
    push @found, $pkgname;
    ++$i;
}

is scalar @found, 200, 'We iterated through 200 packages';

sub check_pkgobjs
{
    my ($pkgnames_ref) = @_;

    my $iter = WWW::AUR::Iterator->new;
    while ( @$pkgnames_ref ) {
        my $pkgname = shift @$pkgnames_ref;
        my $pkg     = $iter->next;
        return 0 unless $pkg->{name} eq $pkgname;
    }
    return 1;
}

ok check_pkgobjs( \@found ), 'Package names and package objects match';
