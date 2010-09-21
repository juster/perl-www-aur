package WWW::AUR::Iterator;

use warnings;
use strict;

use WWW::AUR::UserAgent;
use WWW::AUR::Package;
use WWW::AUR::URI;
use WWW::AUR::Var;

my $PKGENTRY_MATCH = qr{ <tr> \s*
                         <td .*? </td> \s*
                         <td .*? </td> \s*
                         <td .*? >
                          <span [ ] class='f4'>
                           <a [ ] href='packages[.]php[?]ID=\d+'>
                            <span [ ] class='black'>
                             ( \S+ ) }xms;

sub new
{
    my $class  = shift;
    my $self   = bless { @_ }, $class;
    $self->reset();
    return $self;
}

sub reset
{
    my ($self) = @_;
    $self->{curridx}   = 0;
    $self->{finished}  = 0;
    $self->{packages}  = [];
    $self->{useragent} = WWW::AUR::UserAgent->new();
    return;
}

#---HELPER FUNCTION---
sub _pkglist_uri
{
    my ($startidx) = @_;
    return pkg_uri( SB => q{n}, SO => q{a}, O  => $startidx, PP => 100 );
}

#---PRIVATE METHOD---
sub _scrape_pkglist
{
    my ($self) = @_;

    my $uri  = _pkglist_uri( $self->{curridx} );
    my $resp = $self->{useragent}->get( $uri );
    
    Carp::croak 'Failed to GET package list webpage: ' . $resp->status_line
        unless $resp->is_success;

    my @packages = $resp->content =~ /$PKGENTRY_MATCH/xmsg;
    return \@packages;
}

sub next_name
{
    my ($self) = @_;

    return undef if $self->{finished};

    # Load a new batch of packages if our internal list is empty...
    if ( @{ $self->{packages} } == 0 ) {
        my $newpkgs = $self->_scrape_pkglist;
        $self->{curridx} += 100;

        if ( @$newpkgs == 0 ) {
            $self->{finished} = 1;
            return undef;
        }

        $self->{packages} = $newpkgs;
    }

    return shift @{ $self->{packages} };
}

sub next
{
    my ($self) = @_;

    my $next = $self->next_name;
    return ( $next ? WWW::AUR::Package->new( $next, %$self ) : undef );
}

1;
