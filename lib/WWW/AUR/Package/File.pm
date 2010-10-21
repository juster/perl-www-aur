package WWW::AUR::Package::File;

use warnings;
use strict;

use File::Basename qw(basename);
use Archive::Tar   qw();
use File::Spec     qw();
use File::Path     qw(make_path);
use Carp           qw();
use Cwd            qw(getcwd);

use WWW::AUR::PKGBUILD qw();
use WWW::AUR::Var      qw(path_params);

sub new
{
    my $class  = shift;
    my ($path) = @_;

    Carp::croak "$path does not exist or is not readable"
        unless -r $path;

    bless { 'srcpkg_path' => $path,
            path_params( @_ ) }, $class;
}

#---PUBLIC METHOD---
sub pkgbuild
{
    my ($self) = @_;

    return $self->{pkgbuild}
        if $self->{pkgbuild};
    
    my $pbpath = $self->make_src_path( 'PKGBUILD' );
    open my $pbfile, '<', $pbpath or die "open: $!";
    my $pbtext = do { local $/; <$pbfile> };
    close $pbfile;

    $self->{pkgbuild} = WWW::AUR::PKGBUILD->new( $pbtext );
    return $self->{pkgbuild}
}

#---PUBLIC METHOD---
sub name
{
    my ($self) = @_;

    # Only use the PKGBUILD if it is extracted already...
    return $self->pkgbuild->pkgname if $self->{'pkgbuild'};

    # Otherwise parse the filename of the source package.
    my $name = basename( $self->src_pkg_path(), '.src.tar.gz' )
        or die 'Failed to extract package name from filename: '
            . $self->src_pkg_path;

    return $name;
}

#---OBJECT METHOD---
sub extract
{
    my ($self) = @_;

    my $pkgpath = $self->src_pkg_path();
    my $destdir = $self->{extpath};

    make_path( $destdir );
    my $olddir = getcwd();

    eval {
        my $tarball = Archive::Tar->new( $pkgpath )
            or die 'Failed to create Archive::Tar object';

        chdir $destdir or Carp::confess "Failed to chdir to $destdir";

        $tarball->extract()
            or Carp::croak "Failed to extract source package file\nerror:"
                . $tarball->error;
    };

    # ALWAYS chdir back...
    { local $@; chdir $olddir; }

    # Propogates an error if one exists...
    die if $@;

    my $srcpkg_dir = File::Spec->catdir( $destdir, $self->name );
    return $self->{srcpkg_dir} = $srcpkg_dir;
}

#---PUBLIC METHOD---
sub src_pkg_path
{
    my ($self) = @_;
    return $self->{srcpkg_path};
}

#---PUBLIC METHOD---
sub src_dir_path
{
    my ($self) = @_;
    return $self->{srcpkg_dir};
}

#---PUBLIC METHOD---
sub make_src_path
{
    my ($self, $relpath) = @_;
    
    Carp::croak 'You must call extract() before srcdir_file()'
        unless $self->{srcpkg_dir};

    $relpath =~ s{\A/+}{};
    return $self->{srcpkg_dir} . q{/} . $relpath;
}

#---PRIVATE METHOD---
sub _builtpkg_path
{
    my ($self, $pkgdest) = @_;
    my $pkgbuild    = $self->pkgbuild;
    my $arch        = $pkgbuild->arch;

    if ( eval { $arch->[0] eq 'any' } ) {
        $arch = 'any';
    }

    unless ( $arch eq 'any' ) {
        $arch = `uname -m`;
        chomp $arch;
    }

    my $pkgfile = sprintf '%s-%s-%d-%s.pkg.tar.xz',
        $pkgbuild->pkgname, $pkgbuild->pkgver, $pkgbuild->pkgrel, $arch;
    return File::Spec->catfile( $pkgdest, $pkgfile );
}

#---PUBLIC METHOD---
sub build
{
    my ($self, %params) = @_;

    return $self->bin_pkg_path()
        if $self->bin_pkg_path();

    my $srcdir  = $self->src_dir_path || $self->extract();
    my $pkgdest = $params{ pkgdest };
    if ( $pkgdest ) { $pkgdest =~ s{/+\z}{};        }
    else            { $pkgdest = $self->{destpath}; }
    $pkgdest = File::Spec->rel2abs( $pkgdest );

    make_path( $pkgdest );
    my $oldcwd = getcwd();
    chdir $srcdir;

    my $cmd = 'makepkg -f';
    $cmd = "$params{prefix} $cmd" if $params{prefix};
    $cmd = "$cmd $params{args}"   if $params{args};

    if ( $params{quiet} ) { $cmd .= ' 2>&1 >/dev/null'; }
 
    local $ENV{PKGDEST} = $pkgdest;
    ( system $cmd ) == 0
        or die sprintf "makepkg failed to run, error code \%d.\nError",
            $? >> 8;

    chdir $oldcwd;

    my $built_path = $self->_builtpkg_path( $pkgdest );
    die "makepkg succeeded but the package file is missing.\nError"
        unless -f $built_path;
    return $self->{builtpkg_path} = $built_path;
}

#---PUBLIC METHOD---
sub bin_pkg_path
{
    my ($self) = @_;
    return $self->{builtpkg_path};
}


1;

__END__

=head1 NAME

WWW::AUR::Package::File - Load, extract, and build a source package file

=head1 SYNOPSIS

=head1 CONSTRUCTOR

  $OBJ = WWW::AUR::Package::File->new( $PATH, %PATH_PARAMS );

=over 4

=item C<$PATH>

The path to a source package file. These typically end with the
.src.tar.gz suffix.

=item C<%PATH_PARAMS>

Optional path parameters. See L<WWW::AUR/PATH PARAMETERS>.

=back

=head1 METHODS

=head2 extract

  $SRCPKGDIR = $OBJ->extract;

=over 4

=item C<$SRCPKGDIR>

The absolute path to the directory where the source package was
extracted. (This is the directory that is contained in the source
package file, extracted)

=back

=head2 build

  $BINPKGDIR = $OBJ->build( %BUILD_PARAMS? );

Builds the AUR package, using the makepkg utility.

=over 4

=item C<%BUILD_PARAMS> (Optional)

Path parameters can be mixed with build parameters. Several build
parameters can be used to provide arguments to makepkg.

Build parameter keys:

=over 4

=item pkgdest

Overrides where to store the built binary package file.

=item quiet

If set to a true value the makepkg output is redirected to I</dev/null>.

=item prefix

A string to prefix before the makepkg command.

=item args

A string to append to the makepkg command as arguments.

=back

=item C<$BINPKGDIR>

The absolute path to the binary package that was created by running
makepkg.

=back

=head2 src_pkg_path

  undef | $PATH = $OBJ->src_pkg_path;

If I<download> has been called, then the path of the downloaded source
package file is returned. Otherwise C<undef> is returned.

=head2 src_pkg_dir

  undef | $PATH = $OBJ->src_pkg_dir;

If I<extract> has been called, then the path of the extract source
package dir is returned. Otherwise C<undef> is returned.

=head2 bin_pkg_path

  undef | $PATH = $OBJ->bin_pkg_path;

If I<build> has been called, then the path of the built binary package
is returned. Otherwise C<undef> is returned.

=head1 SEE ALSO

=over 4

=item * L<WWW::AUR::Package>

=item * L<WWW::AUR::PKGBUILD>

=item * L<http://www.archlinux.org/pacman/makepkg.8.html>

=back

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
