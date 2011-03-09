package WWW::AUR::Iterator;

use warnings 'FATAL' => 'all';
use strict;

use WWW::AUR::UserAgent qw();
use WWW::AUR::Package   qw();
use WWW::AUR::URI       qw( pkg_uri );
use WWW::AUR            qw( _category_name );

my $PKGID_MATCH = qr{ <td .*? </td> \s*
                      <td .*? </td> \s*
                      <td .*? >
                      <span [ ] class='f4'>
                      <a [ ] href='packages[.]php[?]ID=(\d+)'> }xms;

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
    $self->{'curridx'}   = 0;
    $self->{'finished'}  = 0;
    $self->{'packages'}  = [];
    $self->{'useragent'} = WWW::AUR::UserAgent->new();
    return;
}

#---HELPER FUNCTION---
sub _pkglist_uri
{
    my ($startidx) = @_;
    return pkg_uri( q{SB} => q{n}, q{O}  => $startidx, 
                    q{SO} => q{a}, q{PP} => 100 );
}

#---PRIVATE METHOD---
sub _scrape_pkglist
{
    my ($self) = @_;

    my $uri  = _pkglist_uri( $self->{curridx} );
    my $resp = $self->{useragent}->get( $uri );
    
    Carp::croak 'Failed to GET package list webpage: ' . $resp->status_line
        unless $resp->is_success;

    my @pkginfos;
    my $rows_ref = _split_table_rows( $resp->content );
    shift @$rows_ref; # remove the header column

    for my $rowhtml ( @$rows_ref ) {
        my ($id) = $rowhtml =~ /$PKGID_MATCH/;
        my $cols_ref = _strip_row_cols( $rowhtml );

        # Package id, name, version, category #, and maintainer name.
        my ($name, @ver) = split /\s+/, $cols_ref->[1];
        push @pkginfos, $id, $name, "@ver", @{$cols_ref}[ 2 .. 4 ];
    }

    return \@pkginfos;
}

sub _split_table_rows
{
    my ($html) = @_;
    my @rows = $html =~ m{ <tr> ( .*? ) </tr> }gxs;
    return \@rows;
}

sub _strip_row_cols
{
    my ($rowhtml) = @_;
    my @cols = ( map { s/\A\s+//; s/\s+\z//; $_ }
                 map { s/<[^>]+>//g; $_ }
                 $rowhtml =~ m{ <td [^>]*> ( .*? ) </td> }gxs );
    return \@cols;
}

sub next
{
    my ($self) = @_;

    # There are no more packages to iterate over...
    return undef if $self->{'finished'};

    my @pkginfo = splice @{ $self->{'packages'} }, 0, 6;
    if ( @pkginfo ) {
        my $maint = $pkginfo[5];
        if ( $maint eq 'orphan' ) { undef $maint; }
        return { 'id'         => $pkginfo[0],
                 'name'       => $pkginfo[1],
                 'version'    => $pkginfo[2],
                 'category'   => _category_name( $pkginfo[3] ),
                 'desc'       => $pkginfo[4],
                 'maintainer' => $maint };
    }

    # Load a new batch of packages if our internal list is empty...
    my $newpkgs = $self->_scrape_pkglist;

    $self->{'curridx'} += 100;
    $self->{'packages'} = $newpkgs;
    $self->{'finished'} = 1 if scalar @$newpkgs == 0;

    # Recurse, just avoids code copy/pasting...
    return $self->next();
}

sub next_obj
{
    my ($self) = @_;

    my $next = $self->next;
    return ( $next
             ? WWW::AUR::Package->new( $next->{'name'}, %$self )
             : undef );
}

1;

__END__

=head1 NAME

WWW::AUR::Iterator - An iterator for looping through all AUR packages.

=head1 SYNOPSIS

  my $aurobj = WWW:AUR->new();
  my $iter = $aurobj->iter();

  # or without WWW::AUR:
  my $iter = WWW::AUR::Iterator->new();

  while ( my $pkg = $iter->next_obj ) {
      print $pkg->name, "\n";
  }

  $iter->reset;
  while ( my $p = $iter->next ) {
      print "$_:$p->{$_}\n" for qw{ id name version category desc maintainer };
      print "---\n";
  }

=head1 DESCRIPTION

A B<WWW::AUR::Iterator> object can be used to iterate through I<all>
packages currently listed on the AUR webiste.

=head1 CONSTRUCTOR

  $OBJ = WWW::AUR::Iterator->new( %PATH_PARAMS );

=over 4

=item C<%PATH_PARAMS>

The parameters are the same as the L<WWW::AUR> constructor. These are
propogated to any L<WWW::AUR::Package> objects that are created.

=item C<$OBJ>

A L<WWW::AUR::Iterator> object.

=back

=head1 METHODS

=head2 reset

  $OBJ->reset;

The iterator is reset to the beginning of all packages available in
the AUR. This starts the iteration over just like creating a new
I<WWW::AUR::Iterator> object.

=head2 next

  \%PKGINFO | undef = $OBJ->next();

This package scrapes the L<http://aur.archlinux.org/packages.php>
webpage as if it kept clicking the Next button and recording each
package.

=over 4

=item C<\%PKGINFO>

A hash reference containing all the easily available information about
that particular package. The follow table lists each key and its
corresponding value.

  |------------+------------------------------------------------|
  | NAME       | VALUE                                          |
  |------------+------------------------------------------------|
  | id         | The AUR ID number of the package.              |
  | name       | The name (pkgname) of the package.             |
  | desc       | The description (pkgdesc) of the package.      |
  | category   | The AUR category name assigned to the package. |
  | maintainer | The name of the maintainer of the package.     |
  |------------+------------------------------------------------|

=item C<undef>

If we have iterated through all packages, then C<undef> is returned.

=back

=head2 next_obj

  $PKGOBJ | undef = $OBJ->next_obj();

This package is like the L</next> method above but creates a new
object as a convenience. Keep in mind an HTTP request to AUR must be
made when creating a new WWW::AUR::Package object.  Use the L</next>
method if you can, it is faster.

=over 4

=item C<$PKGOBJ>

A L<WWW::AUR::Package> object representing the next package in the AUR.

=item C<undef>

If we have iterated through all packages, then C<undef> is returned.

=back

=head1 SEE ALSO

L<WWW::AUR>

=head1 AUTHOR

Justin Davis, C<< <juster at cpan dot org> >>

=head1 BUGS

Please email me any bugs you find. I will try to fix them as quick as I can.

=head1 SUPPORT

Send me an email if you have any questions or need help.

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Justin Davis.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
