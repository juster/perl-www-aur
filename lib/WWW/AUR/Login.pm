package WWW::AUR::Login;

use warnings 'FATAL' => 'all';
use strict;

use HTTP::Cookies  qw();
use Carp           qw();

use WWW::AUR::Maintainer;
use WWW::AUR::UserAgent;
use WWW::AUR::URI;
use WWW::AUR qw( _category_index );

our @ISA = qw(WWW::AUR::Maintainer);

my $UPLOADURI      = "https://$WWW::AUR::HOST/pkgsubmit.php";
my $COOKIE_NAME    = 'AURSID';
my $BAD_LOGIN_MSG  = 'Bad username or password.';
my $PKG_EXISTS_MSG = ( 'You are not allowed to overwrite the '
                       . '<b>.*?</b> package.' );
my $PKG_EXISTS_ERR = 'You tried to submit a package you do not own';

my $PKGOUTPUT_MATCH = qr{ <p [ ] class="pkgoutput"> ( [^<]+ ) </p> }xms;

sub _new_cookie_jar
{
    my $jar = HTTP::Cookies->new();

    my ($domain, $port) = split /:/, $WWW::AUR::HOST;
    $port ||= 443; # we use https for logins

    # This REALLY should take a hash as argument...
    $jar->set_cookie( 0, 'AURLANG' => 'en', # version, key, val
                      '/', $domain, $port,  # path, domain, port
                      0, 0,                 # path_spec, secure
                      0, 0,                 # maxage, discard
                      {} );                 # rest

    return $jar;
}

sub new
{
    my $class = shift;

    Carp::croak 'You must supply a name and password as argument'
        unless @_ >= 2;
    my ($name, $password) = @_;

    my $ua   = WWW::AUR::UserAgent->new( agent      => $WWW::AUR::USERAGENT,
                                         cookie_jar => _new_cookie_jar());
    my $resp = $ua->post( "https://$WWW::AUR::HOST/index.php",
                          [ user => $name, passwd => $password ] );

    Carp::croak 'Failed to login to AUR: bad username or password'
        if $resp->content =~ /$BAD_LOGIN_MSG/;

    unless ( $resp->code == 302 ) {
        Carp::croak 'Failed to login to AUR: ' . $resp->status_line
            unless $resp->is_success;
    }

    my $self = $class->SUPER::new( $name );
    $self->{'useragent'} = $ua;
    return $self;
}

my %_PKG_ACTIONS = map { ( lc $_ => "do_$_" ) }
    qw{ Adopt Disown Vote UnVote Notify UnNotify Flag UnFlag Delete };

sub _do_pkg_action
{
    my ($self, $act, $pkg, @params) = @_;

    Carp::croak 'Please provide a proper package ID/name/obj argument'
        unless $pkg;

    my $action = $_PKG_ACTIONS{ $act }
        or Carp::croak "$act is not a valid action for a package";

    my $id   = _pkgid( $pkg );
    my $ua   = $self->{'useragent'};
    my $uri  = pkg_uri( 'https' => 1, 'ID' => $id );
    my $resp = $ua->post( $uri, [ "IDs[$id]" => 1,
                                  'ID'       => $id,
                                  $action    => 1,
                                  @params ] );

    Carp::croak 'Failed to send package action: ' . $resp->status_line
        unless $resp->is_success;

    my ($pkgoutput) = $resp->content =~ /$PKGOUTPUT_MATCH/;
    Carp::confess 'Failed to parse package action response'
        unless $pkgoutput;

    return $pkgoutput;
}

#---HELPER FUNCTION---
sub _pkgid
{
    my $pkg = shift;

    if ( ! ref $pkg ) {
        return $pkg if $pkg =~ /\A\d+\z/;

        require WWW::AUR::Package;
        my $pkgobj = WWW::AUR::Package->new( $pkg );
        return $pkgobj->id;
    }

    Carp::croak 'You must provide a package name, id, or object'
        unless eval { $pkg->isa( 'WWW::AUR::Package' ) };

    return $pkg->id;
}

#---HELPER FUNCTION---
# If provided pkg is an object, call its name method, otherwise pass through.
sub _pkgdesc
{
    my ($pkg) = @_;
    my $name;
    return $name if $name = eval { $pkg->name };
    return $pkg;
}

sub _def_action_method
{
    my ($name, $goodmsg) = @_;
    
    no strict 'refs';
    *{ $name } = sub {
        my ($self, $pkg) = @_;

        my $txt = $self->_do_pkg_action( $name => $pkg );
        unless ( $txt =~ /\A$goodmsg/ ) {
            Carp::confess sprintf qq{%s action on "%s" failed:\n%s\n},
                ucfirst $name, _pkgdesc( $pkg ), $txt;
        }
        return $txt;
    };

    return;
}

my %_ACTIONS = ( 'adopt'    => 'The selected packages have been adopted.',
                 'disown'   => 'The selected packages have been disowned.',

                 'vote'     => ( 'Your votes have been cast for the selected '
                                 . 'packages.' ),
                 'unvote'   => ( 'Your votes have been removed from the '
                                 . 'selected packages.' ),

                 'notify'   => ( 'You have been added to the comment '
                                 . 'notification list for' ),
                 'unnotify' => ( 'You have been removed from the comment '
                                 . 'notification ist for' ),

                 'flag'     => ( 'The selected packages have been flagged '
                                 . 'out-of-date.' ),
                 'unflag'   => 'The selected packages have been unflagged.',
                );

while ( my ($name, $goodmsg) = each %_ACTIONS ) {
    _def_action_method( $name, $goodmsg );
}

sub delete
{
    my ($self, $pkg) = @_;

    my $txt = $self->_do_pkg_action( 'delete'         => $pkg,
                                     'confirm_Delete' => 1 );

    unless ( $txt =~ /\AThe selected packages have been deleted[.]/ ) {
        my $msg = sprintf q{Failed to perform the delete action on }
            . q{package "%s"}, _pkgdesc( $pkg );
        Carp::croak $msg;
    }

    return $txt;

}

sub upload
{
    my ($self, $pkgfile_path, $catname) = @_;

    Carp::croak "Given file path ($pkgfile_path) does not exist"
        unless -f $pkgfile_path;

    my $catidx = _category_index( $catname );
    my $ua     = $self->{useragent};
    my $resp   = $ua->post( $UPLOADURI,
                            'Content-Type' => 'form-data',
                            'Content'      =>
                            [ category  => $catidx,
                              submit    => 'Upload',
                              pkgsubmit => 1,
                              pfile     => [ $pkgfile_path ],
                             ] );

    Carp::croak $PKG_EXISTS_ERR if $resp->content =~ /$PKG_EXISTS_MSG/;

    return;
}

# Create a nifty alias, to match the "My Packages" AUR link...
*my_packages = \&WWW::AUR::Maintainer::packages;

1;

__END__

=head1 NAME

WWW::AUR::Login - Login to the AUR and manage packages, vote, etc.

=head1 SYNOPSIS

  my $login = $aurobj->login( 'whoami', 'password' )
      or die 'failed to login as whoami';
  
  # or ...
  
  my $login = eval { WWW::AUR::Login->( 'whoami', 'password' ) };
  die 'failed to login as whoami' if $@;
  
  # You can use package names for actions...
  $login->adopt( 'my-new-package');
  $login->disown( 'not-my-problem' );
  
  # Or package IDs for actions...
  $login->vote( 12353 );
  $login->unvote( 12353 );

  # Or package objects for actions...
  $login->notify( WWW::AUR::Package->new( 'interesting-package' ));
  $login->unnotify( WWW::AUR::Package->new( 'boring-package' ));
  
  # Flagging packages out of date...
  $login->flag( 'out-of-date-package' );
  $login->unflag( 'up-to-date-package' );
  
  # Upload a new package file...
  $login->upload( '/path/to/package-file.src.tar.gz', 'devel' );
  
  # Use the inherited WWW::AUR::Maintainer accessors.
  my $name     = $login->name;
  my @packages = $login->packages;

=head1 DESCRIPTION

This module provides an interface for the AUR package maintainer to
perform I<almost> any action they could perform on the
website. Commenting has not yet been implemented.

B<WWW::AUR::Login> is a sub-class of L<WWW::AUR::Maintainer>.

=head1 CONSTRUCTOR

  $OBJ = WWW::AUR::Login->new( $USERNAME, $PASSWORD )

=over 4

=item C<$USERNAME>

The AUR user name to login as.

=item C<$PASSWORD>

The password needed to login as the specified user.

=item B<Errors>

The following errors messages are thrown with C<Carp::croak> if we
were unable to login to the AUR.

=over 4

=item Failed to login to AUR: bad username or password

We could not login because either the username doesn't exist or
the password for the username is incorrect.

=item Failed to login to AUR: I<< <LWP error> >>

If LWP failed to retrieve the page because of some problem with the
HTTP request an HTTP status code and short message is given at
I<< <LWP error> >>.

=back

=back

=head1 METHODS

=head2 adopt disown [un]vote [un]notify [un]flag

  $MSG = $OBJ->adopt( $PKGID | $PKGNAME | $PKGOBJ );
  $MSG = $OBJ->disown( $PKGID | $PKGNAME | $PKGOBJ );
  $MSG = $OBJ->unvote( $PKGID | $PKGNAME | $PKGOBJ );
  $MSG = $OBJ->vote( $PKGID | $PKGNAME | $PKGOBJ );
  $MSG = $OBJ->unnotify( $PKGID | $PKGNAME | $PKGOBJ );
  $MSG = $OBJ->notify( $PKGID | $PKGNAME | $PKGOBJ );
  $MSG = $OBJ->unflag( $PKGID | $PKGNAME | $PKGOBJ );
  $MSG = $OBJ->flag( $PKGID | $PKGNAME | $PKGOBJ );
  $MSG = $OBJ->delete( $PKGID | $PKGNAME | $PKGOBJ );

If you are an AUR maintainer you already know what these do. These
actions are the same actions you can perform to a package (with
buttons on the webpage) when you are logged in.

In order to use the delete method you must be logged in as a
Trusted User.

=over 4

=item C<$MSG>

This is the message displayed at the top of the page by the AUR after
an action is completed. Not really useful but there it is.

=item C<$PKGID>

The ID of the package. You can see this on a package's webpage after
the C<?ID=>. You can also use a L<WWW::AUR::Package> object's C<id>
method. Interally, the ID is what is passed as a parameter to the AUR
action script.

=item C<$PKGNAME>

The name of the package you want to perform the action on. The package
is looked up in order to find the ID number.

=item C<$PKGOBJ>

A L<WWW::AUR::Package> object.

=item B<Errors>

=over 4

=item Failed to find package: I<< <Package Name> >>

This happens when you pass a package name as argument to an action
but no package with that name exists.

=item Failed to send package action: I<< <LWP Error> >>

Some low level error with the HTTP request occurred. The HTTP status
code and a short message describing the problem is inserted at
I<< <LWP Error> >>.

=item Failed to parse package action response

The code examines the HTML that is sent to it in response to an
attempted action. When we scraped the HTML it did not match the output
we expected. Maybe the AUR website was changed and this module wasn't
updated?

=item I<< <action> >> action on I<< <package> >> failed:\n<< <AUR message> >>

This hardly happens. If this does it is probably an internal error.
A stack-trace is printed out. I<< <action> >> is the name of the
action method, I<< <package> >> is the argument passed to the
method (converted to a name if possible), I<< <AUR message> >>
is the message the AUR prints at the top of the webpage.

=back

=back

=head2 upload

  $OBJ->upload( $SRCPKG_PATH, $CATEGORY );

This method submits a new package to the AUR by uploading a source
package file. Just point it to a source package file and specify which
category to assign the package to.

=over 4

=item C<$SRCPKG_PATH>

The path to a source package file to upload/submit to the AUR.

=item C<$CATEGORY>

Every package in the AUR belongs to a category. This may be useful
someday. You will have to choose which category your package should
belong to. The category is given as a string and must be one of the
following:

=over 4

=item * daemons

=item * devel

=item * editors

=item * emulators

=item * games

=item * gnome

=item * i18n

=item * kde

=item * kernels

=item * lib

=item * modules

=item * multimedia

=item * network

=item * office

=item * science

=item * system

=item * x11

=item * xfce

=back

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

=cut
