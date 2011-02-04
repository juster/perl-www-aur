package WWW::AUR::PKGBUILD;

use warnings 'FATAL' => 'all';
use strict;

use Fcntl          qw(SEEK_SET);
use Carp           qw();

sub new
{
    my $class = shift;
    my $self  = bless {}, $class;

    if ( @_ ) { $self->read( @_ ); }
    return $self;
}

#---HELPER FUNCTION---
sub _unquote_bash
{
    my ($bashtext, $start) = @_;
    my $elem;

    $start ||= 0;
    ( pos $bashtext ) = $start;

    # Extract the values of a bash array...
    if ( $bashtext =~ / \G [(] ([^)]*) [)] /gcx ) {
        my $arrtext = $1;
        my @result;

        ARRAY_LOOP:
        while ( 1 ) {
            my ($elem, $elem_end) = _unquote_bash( $arrtext, pos $arrtext );
            push @result, $elem if $elem;

            # There should only be spaces leftover.
            ( pos $arrtext ) = $elem_end;
            last ARRAY_LOOP if ( $elem_end >= length $arrtext ||
                                 $arrtext !~ /\G\s+/g );
        }

        # Arrays are special, we do not recurse after we find one.
        return \@result, pos $bashtext;
    }

    # The rest is for string "parsing"...

    # Single quoted strings cannot escape the quote (')...
    if ( $bashtext =~ /\G'([^']*)'/gc ) {
        $elem = $1;
    }
    # Double quoted strings can...
    elsif ( $bashtext =~ /\G"/gc ) {
        my $beg = pos $bashtext;
        # Skip past escaped double-quotes and non-double-quote chars.
        while ( $bashtext =~ / \G (?: \\" | [^"] ) /gcx ) { ; }

        $elem = substr $bashtext, $beg, ( pos $bashtext ) - $beg;
        ++( pos $bashtext ); # skip the closing "
    }
    # Otherwise regular words are treated as one element...
    elsif ( $bashtext =~ /\G([^ \n\t'"]+)/gc ) {
        $elem = $1;
    }
    # If none of the above matches, then we stop recursion.
    else { return q{}, $start; }

    # We recurse in order to concatenate adjacent strings.
    my ( $next_elem, $next_end ) = _unquote_bash( $bashtext, pos $bashtext );
    return ( $elem . $next_elem, $next_end );
}

#---HELPER FUNCTION---
sub _depstr_to_hash
{
    my ($depstr) = @_;
    my ($pkg, $cmp, $ver) = $depstr =~ / \A ([\w_-]+)
                                         (?: ([=<>]=?)
                                             ([\w._-]+) )? \z/xms;

    Carp::croak "Failed to parse depend string: $_" unless $pkg;

    $cmp ||= q{>};
    $ver ||= 0;
    return +{ 'pkg' => $pkg, 'cmp' => $cmp,
              'ver' => $ver, 'str' => $depstr };
}

#---HELPER FUNCTION---
sub _pkgbuild_fields
{
    my ($pbtext) = @_;

    my %pbfields;
    while ( $pbtext =~ / \G .*? \n? ^ (\w+) = /gxms ) { 
        my $name = $1;
        my ( $value, $endpos ) = _unquote_bash( $pbtext, pos $pbtext );

        $pbfields{ $name } = $value;
        ( pos $pbtext ) = $endpos;
    }

    for my $depkey ( qw/ depends conflicts / ) {
        my @fixed;

        @fixed = map { _depstr_to_hash($_) } @{$pbfields{ $depkey }}
            if $pbfields{ $depkey };

        $pbfields{ $depkey } = \@fixed;
    }
    
    return %pbfields;
}

#---HELPER FUNCTION---
sub _slurp
{
    my ($fh) = @_;

    # Make sure we start reading from the beginning of the file...
    seek $fh, SEEK_SET, 0 or die "seek: $!";

    local $/;
    return <$fh>;
}

sub read
{
    my $self = shift;
    $self->{'text'} = ( ref $_[0] eq 'IO' ? _slurp( shift ) : shift );

    my %pbfields = _pkgbuild_fields( $self->{'text'} );
    $self->{'fields'} = \%pbfields;    
    return %pbfields;
}

sub fields
{
    my ($self) = @_;
    return %{ $self->{'fields'} }
}

sub _def_field_acc
{
    my ($name) = @_;

    no strict 'refs';
    *{ $name } = sub {
        my ($self) = @_;
        my $val = $self->{'fields'}{$name};

        return q{} unless defined $val;
        return $val;
    }
}

_def_field_acc( $_ ) for qw{ pkgname pkgver pkgdesc pkgrel url
                             license install changelog source
                             noextract md5sums sha1sums sha256sums
                             sha384sums sha512sums groups arch
                             backup depends makedepends optdepends
                             conflicts provides replaces options };

1;

__END__

=head1 NAME

WWW::AUR::PKGBUILD - Parse PKGBUILD files created for makepkg

=head1 SYNOPSIS

  use WWW::AUR::PKGBUILD;
  
  # Read a PKGBUILD from a file handle...
  open my $fh, '<', 'PKGBUILD' or die "open: $!";
  my $pb = WWW::AUR::PKGBUILD->new( $fh );
  close $fh;
  
  # Or read from text
  my $pbtext = do { local (@ARGV, $/) = 'PKGBUILD'; <> };
  my $pbobj  = WWW::AUR::PKGBUILD->new( $pbtext );
  my %pb     = $pbobj->fields();

  # Array fields are converted into arrayrefs...
  my $deps = join q{, }, @{ $pb{depends} };
  
  my %pb = $pb->fields();
  print <<"END_PKGBUILD";
  pkgname = $pb{pkgname}
  pkgver  = $pb{pkgver}
  pkgdesc = $pb{pkgdesc}
  depends = $deps
  END_PKGBUILD
  
  # There are also method accessors for all fields
  

=head1 DESCRIPTION

This class reads the text contents of a PKGBUILD file and does some
primitive parsing. PKGBUILD fields (ie pkgname, pkgver, pkgdesc) are
extracted into a hash. Bash arrays are extracted into an arrayref
(ie depends, makedepends, source).

Remember, bash is more lenient about using arrays than perl is. Bash
treats one-element arrays the same as non-array parameters and
vice-versa. Perl doesn't. I might use a module to copy bash's behavior
later on.

=head1 CONSTRUCTOR

  $OBJ = WWW::AUR::PKGBUILD->new( $PBTEXT | $PBFILE );

All this does is create a new B<WWW::AUR::PKGBUILD> object and
then call the L</read> method with the provided arguments.

=over 4

=item C<$PBTEXT>

A scalar containing the text of a PKGBUILD file.

=item C<$PBFILE>

A filehandle of an open PKGBUILD file.

=back

=head1 METHODS

=head2 fields

  %PBFIELDS = $OBJ->fields();

=over 4

=item C<%PBFIELDS>

The fields and values of the PKGBUILD. Bash arrays (those values defined
with parenthesis around them) are converted to array references.

=back

=head2 read

  %PBFIELDS = $OBJ->read( $PBTEXT | $PBFILE );

=over 4

=item C<$PBTEXT>

A scalar containing the text of a PKGBUILD file.

=item C<$PBFILE>

A filehandle of an open PKGBUILD file.

=item C<%PBFIELDS>

The fields and values of the PKGBUILD. Bash arrays (those values defined
with parenthesis around them) are converted to array references.

=back

=head2 PKGBUILD Field Accessors

  undef | $TEXT | $AREF = ( $OBJ->pkgname     | $OBJ->pkgver     |
                            $OBJ->pkgdesc     | $OBJ->url        |
                            $OBJ->license     | $OBJ->install    |
                            $OBJ->changelog   | $OBJ->source     |
                            $OBJ->noextract   | $OBJ->md5sums    |
                            $OBJ->sha1sums    | $OBJ->sha256sums |
                            $OBJ->sha384sums  | $OBJ->sha512sums |
                            $OBJ->groups      | $OBJ->arch       |
                            $OBJ->backup      | $OBJ->depends    |
                            $OBJ->makedepends | $OBJ->optdepends |
                            $OBJ->conflicts   | $OBJ->provides   |
                            $OBJ->replaces    | $OBJ->options    )

Each standard field of a PKGBUILD can be accessed by using one
of these accessors. The L</fields> method returns a hashref
containing ALL bash variables defined globally.

=over 4

=item C<undef>

If the field was not defined in the PKGBUILD undef is returned.

=item C<$TEXT>

If a field is defined but is not a bash array it is returned as a
scalar text value.

=item C<$AREF>

If a field is defined as a bash array (with parenthesis) it is
returned as an array reference.

=back

=head1 SEE ALSO

=over 4

=item * L<WWW::AUR::Package::File>

=item * L<http://www.archlinux.org/pacman/PKGBUILD.5.html>

=back

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
