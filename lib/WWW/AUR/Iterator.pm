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

__END__

=head1 NAME

WWW::AUR::Iterator - An iterator for looping through all AUR packages.

=head1 SYNOPSIS

  my $iter = $aurobj->packages;
  # or my $iter = WWW::AUR::Iterator->new();

  while ( my $pkg = $iter->next ) {
      print $pkg->name, "\n";
  }

  $iter->reset;
  while ( my $pkgname = $iter->next_name ) {
      print "$pkgname\n";
  }

=head1 DESCRIPTION

A B<WWW::AUR::Iterator> object can be used to iterate through I<all>
packages currently listed on the AUR webiste.

=head1 CONSTRUCTOR

  $OBJ = WWW::AUR::Iterator->new( %PATH_PARAMS );

=over 4

=item Parameters

The parameters are the same as the L<WWW::AUR> constructor. These are
propogated to any L<WWW::AUR::Package> objects that are created.

=back

=over 4

=item Returns

=over 4

=item C<$OBJ>

A L<WWW::AUR::Iterator> object.

=back

=back

=head1 METHODS

=head2 reset

  $OBJ->reset;

The iterator is reset to the beginning of all packages available in
the AUR. This starts the iteration over just like creating a new
I<WWW::AUR::Iterator> object.

=head2 next

  $PKGOBJ | undef = $OBJ->next();

=over 4

=item Returns

=over 4

=item C<$PKGOBJ>

A L<WWW::AUR::Package> object representing the next package in the AUR.

=item I<undef>

If we have iterated through all packages, then I<undef> is returned.

=back

=back

=head2 next_name

  $PKGNAME | undef = $OBJ->next_name();

=over 4

=item Returns

=over 4

=item C<$PKGNAME>

The name of the next package in the AUR. This is faster than
L<METHODS/next> because L<WWW::AUR::Package> objects do not have to be
created for every package on the AUR.

=item I<undef>

If we have iterated through all packages, then I<undef> is returned.

=back

=back

=head1 SEE ALSO

L<WWW::AUR>

=head1 AUTHOR

Justin Davis, C<< <juster at cpan dot org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-aur at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-AUR>.  I will be
notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

Send me an email at the above address if you have any questions or
need help.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Justin Davis.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
